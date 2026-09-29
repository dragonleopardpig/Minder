using Gdk;
using GLib;

public class RasterVectorizer : Object {

  private const int COMMAND_TIMEOUT = 30;

  private static string? find_command() {
    var configured = Environment.get_variable( "MINDER_POTRACE" );
    if( (configured != null) && (configured.strip() != "") ) {
      if( configured.contains( "/" ) ) {
        return( FileUtils.test( configured, FileTest.IS_EXECUTABLE ) ? configured : null );
      }
      return( Environment.find_program_in_path( configured ) );
    }
    return( Environment.find_program_in_path( "potrace" ) );
  }

  public static bool available() {
    return( find_command() != null );
  }

  public static async string convert( Pixbuf image ) throws Error {
    var command = find_command();
    if( command == null ) {
      throw new IOError.NOT_FOUND( _( "Potrace is not installed" ) );
    }

    string? temp_dir = null;
    string? bitmap_path = null;
    string? svg_path = null;
    try {
      temp_dir = DirUtils.make_tmp( "minder-vector-XXXXXX" );
      bitmap_path = GLib.Path.build_filename( temp_dir, "image.pbm" );
      svg_path = GLib.Path.build_filename( temp_dir, "image.svg" );
      FileUtils.set_data( bitmap_path, make_bitmap( image ) );

      string[] argv = {
        command, "-s", "-t", "2", "-O", "0.2",
        "-W", "%dpt".printf( image.width ),
        "-H", "%dpt".printf( image.height ),
        "-o", svg_path, bitmap_path
      };
      var launcher = new SubprocessLauncher(
        SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
      );
      var process = launcher.spawnv( argv );
      string? stdout_buf = null;
      string? stderr_buf = null;
      var timed_out = false;
      var timeout_id = Timeout.add_seconds( COMMAND_TIMEOUT, () => {
        timed_out = true;
        process.force_exit();
        return( Source.REMOVE );
      });

      try {
        yield process.communicate_utf8_async( null, null, out stdout_buf, out stderr_buf );
      } finally {
        if( !timed_out ) {
          Source.remove( timeout_id );
        }
      }

      if( timed_out ) {
        throw new IOError.TIMED_OUT( _( "Image tracing timed out" ) );
      }
      if( !process.get_successful() ) {
        throw new IOError.FAILED( (stderr_buf ?? stdout_buf ?? _( "Image tracing failed" )).strip() );
      }

      string svg;
      FileUtils.get_contents( svg_path, out svg );
      return( theme_svg( svg, image.width, image.height ) );
    } finally {
      if( bitmap_path != null ) FileUtils.remove( bitmap_path );
      if( svg_path != null ) FileUtils.remove( svg_path );
      if( temp_dir != null ) DirUtils.remove( temp_dir );
    }
  }

  private static uint8[] make_bitmap( Pixbuf image ) {
    var header = "P4\n%d %d\n".printf( image.width, image.height );
    var byte_width = (image.width + 7) / 8;
    var bitmap = new uint8[header.length + (byte_width * image.height)];
    for( int index=0; index<header.length; index++ ) {
      bitmap[index] = (uint8)header[index];
    }

    unowned uint8[] pixels = image.get_pixels();
    for( int row=0; row<image.height; row++ ) {
      for( int column=0; column<image.width; column++ ) {
        var pixel = (row * image.rowstride) + (column * image.n_channels);
        var alpha = image.has_alpha ? (int)pixels[pixel + 3] : 255;
        var brightness = ((299 * pixels[pixel]) + (587 * pixels[pixel + 1]) +
                          (114 * pixels[pixel + 2])) / 1000;
        var composited = ((brightness * alpha) + (255 * (255 - alpha))) / 255;
        if( composited < 128 ) {
          var offset = header.length + (row * byte_width) + (column / 8);
          bitmap[offset] = (uint8)(bitmap[offset] | (1 << (7 - (column % 8))));
        }
      }
    }
    return( bitmap );
  }

  private static string theme_svg( string source, int width, int height ) throws Error {
    var svg = source;
    var start = svg.index_of( "<!DOCTYPE" );
    if( start != -1 ) {
      var end = svg.index_of( ">", start );
      if( end != -1 ) {
        svg = svg.substring( 0, start ) + svg.substring( end + 1 );
      }
    }

    svg = svg.replace( "width=\"%fpt\"".printf( (double)width ),
                       "width=\"%d\"".printf( width ) );
    svg = svg.replace( "height=\"%fpt\"".printf( (double)height ),
                       "height=\"%d\"".printf( height ) );
    if( !svg.contains( "fill=\"#000000\"" ) ) {
      throw new IOError.INVALID_DATA( _( "Potrace returned an unexpected SVG" ) );
    }
    svg = svg.replace( "fill=\"#000000\"", "fill=\"currentColor\"" );
    return( svg.replace(
      "<g transform=",
      "<style>\n" +
      "  :root { color: #111; }\n" +
      "  @media (prefers-color-scheme: dark) {\n" +
      "    :root { color: #f5f5f5; }\n" +
      "  }\n" +
      "</style>\n" +
      "<g transform="
    ) );
  }

}

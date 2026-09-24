/*
* Copyright (c) 2018-2026 (https://github.com/phase1geo/Minder)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation; either version 2 of
* the License, or (at your option) any later version.
*/

namespace MinderTest {

  public class LatexSpanParserTest : TestSuite {

    public LatexSpanParserTest() {
      this.add_test( "valid-source", test_valid_source );
      this.add_test( "invalid-source", test_invalid_source );
      this.add_test( "escaped-delimiters", test_escaped_delimiters );
      this.add_test( "position", test_position );
      this.add_test( "display-environments", test_display_environments );
    }

    private void test_valid_source() {
      Assert.true( LatexSpanParser.is_latex_source( "before $$x_1$$ after" ) );
      Assert.true( LatexSpanParser.is_latex_source( "$$x$$ and $$\\frac{1}{2}$$" ) );
      Assert.true( LatexSpanParser.is_latex_source( "before $x_1$ after" ) );
      Assert.true( LatexSpanParser.is_latex_source( "$x$ and $$\\frac{1}{2}$$" ) );
    }

    private void test_invalid_source() {
      Assert.false( LatexSpanParser.is_latex_source( "ordinary text" ) );
      Assert.false( LatexSpanParser.is_latex_source( "before $$x" ) );
      Assert.false( LatexSpanParser.is_latex_source( "before $$$$ after" ) );
      Assert.false( LatexSpanParser.is_latex_source( "$$x$$ and $$" ) );
      Assert.false( LatexSpanParser.is_latex_source( "before $x" ) );
      Assert.false( LatexSpanParser.is_latex_source( "before $ x $ after" ) );
      Assert.false( LatexSpanParser.is_latex_source( "the price is $5" ) );
    }

    private void test_escaped_delimiters() {
      Assert.false( LatexSpanParser.is_latex_source( "escaped \\$$ only" ) );
      Assert.true( LatexSpanParser.is_latex_source( "escaped \\$$ then $$x$$" ) );
      Assert.true( LatexSpanParser.is_latex_source( "two slashes \\\\$$x$$" ) );
      Assert.true( LatexSpanParser.is_latex_source( "$$x \\$$ y$$" ) );
      Assert.false( LatexSpanParser.is_latex_source( "escaped \\$x$ only" ) );
      Assert.true( LatexSpanParser.is_latex_source( "escaped \\$5 then $x$" ) );
      Assert.true( LatexSpanParser.is_escaped_dollar( "\\$5", 1 ) );
      Assert.false( LatexSpanParser.is_escaped_dollar( "\\\\$5", 2 ) );
    }

    private void test_position() {
      var source = "α before $$x_1$$ after";
      Assert.false( LatexSpanParser.is_latex_at( source, source.index_of( "before" ) ) );
      Assert.true( LatexSpanParser.is_latex_at( source, source.index_of( "$$" ) ) );
      Assert.true( LatexSpanParser.is_latex_at( source, source.index_of( "x_1" ) ) );
      Assert.false( LatexSpanParser.is_latex_at( source, source.last_index_of( "$$" ) ) );
      Assert.true( LatexSpanParser.is_latex_at( "pending $$x", 11 ) );

      var inline_source = "price $5 and formula $x_1$ after";
      Assert.false( LatexSpanParser.is_latex_at( inline_source, inline_source.index_of( "5" ) ) );
      Assert.true( LatexSpanParser.is_latex_at( inline_source, inline_source.index_of( "x_1" ) ) );
      Assert.false( LatexSpanParser.is_latex_at( inline_source, inline_source.index_of( "after" ) ) );
      Assert.true( LatexSpanParser.is_latex_at( "pending $x", 9 ) );
    }

    private void test_display_environments() {
      Assert.string_compare(
        "\\begin{aligned}x&=1\\\\y&=2\\end{aligned}",
        LatexSpanParser.normalize_expression(
          "\\begin{align*}x&=1\\\\y&=2\\end{align*}"
        )
      );
      Assert.string_compare(
        "\\begin{gathered}x\\\\y\\end{gathered}",
        LatexSpanParser.normalize_expression(
          "\\begin{gather}x\\\\y\\end{gather}"
        )
      );
      Assert.string_compare(
        "\\begin{array}{cc}x&y\\end{array}",
        LatexSpanParser.normalize_expression(
          "\\begin{array}{cc}x&y\\end{array}"
        )
      );
    }

  }

}

/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa

struct AttributesRun {

  var location: CGPoint
  var cells: ArraySlice<UCell>
  var attrs: CellAttributes
}

struct FontGlyphRun {

  var font: NSFont
  var glyphs: [CGGlyph]
  var positions: [CGPoint]
}

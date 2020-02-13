/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Foundation

func identity<T>(_ input: T) -> T { input }

extension BinaryFloatingPoint {

  var cgf: CGFloat { CGFloat(self) }
}

extension FixedWidthInteger {

  var cgf: CGFloat { CGFloat(self) }
}

extension String {

  func without(prefix: String) -> String {
    guard self.hasPrefix(prefix) else { return self }

    let idx = self.index(self.startIndex, offsetBy: prefix.count)
    return String(self[idx..<self.endIndex])
  }
}

extension Array where Element: Equatable {

  func removingDuplicatesPreservingFromBeginning() -> [Element] {
    var result = [Element]()

    for value in self {
      if result.contains(value) == false { result.append(value) }
    }

    return result
  }

  /**
   Returns an array where elements of `elements` contained in the array are substituted
   by elements of `elements`. This is useful when you need pointer equality
   rather than `Equatable`-equality like in `NSOutlineView`.

   If an element of `elements` is not contained in the array, it's ignored.
   */
  func substituting(elements: [Element]) -> [Element] {
    let elementsInArray = elements.filter { self.contains($0) }
    let indices = elementsInArray.compactMap { self.firstIndex(of: $0) }

    var result = self
    indices.enumerated().forEach { result[$0.1] = elementsInArray[$0.0] }

    return result
  }
}

extension Array where Element: Hashable {

  func toDict<V>(by mapper: @escaping (Element) -> V) -> Dictionary<Element, V> {
    var result = Dictionary<Element, V>(minimumCapacity: self.count)
    self.forEach { result[$0] = mapper($0) }

    return result
  }

  // From https://stackoverflow.com/a/46354989
  func uniqueing() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

func tuplesToDict<K: Hashable, V, S: Sequence>(_ sequence: S)
    -> Dictionary<K, V> where S.Iterator.Element == (K, V) {
  var result = Dictionary<K, V>(minimumCapacity: sequence.underestimatedCount)

  for (key, value) in sequence { result[key] = value }

  return result
}

extension Dictionary {

  func mapToDict<K, V>(_ transform: ((key: Key, value: Value)) throws -> (K, V)) rethrows
      -> Dictionary<K, V> {
    let array = try self.map(transform)
    return tuplesToDict(array)
  }

  func flatMapToDict<K, V>(_ transform: ((key: Key, value: Value)) throws -> (K, V)?) rethrows
      -> Dictionary<K, V> {
    let array = try self.compactMap(transform)
    return tuplesToDict(array)
  }
}

extension Sequence {

  @discardableResult
  func log() -> Self {
    self.forEach { Swift.print($0) }
    return self
  }
}

// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/standard_resolution_map.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';

/**
 * Returns the [Element] exported from the given [LibraryElement].
 */
Element getExportedElement(LibraryElement library, String name) {
  if (library == null) {
    return null;
  }
  return getExportNamespaceForLibrary(library)[name];
}

/**
 * Returns the export namespace of the given [LibraryElement].
 */
Map<String, Element> getExportNamespaceForLibrary(LibraryElement library) {
  Namespace namespace =
      new NamespaceBuilder().createExportNamespaceForLibrary(library);
  return namespace.definedNames;
}

/**
 * Return the [ImportElement] that is referenced by [prefixNode], or `null` if
 * the node does not reference a prefix or if we cannot determine which import
 * is being referenced.
 */
ImportElement getImportElement(SimpleIdentifier prefixNode) {
  AstNode parent = prefixNode.parent;
  if (parent is ImportDirective) {
    return parent.element;
  }
  return internal_getImportElementInfo(prefixNode);
}

/**
 * Return the [ImportElement] that declared [prefix] and imports [element].
 *
 * [libraryElement] - the [LibraryElement] where reference is.
 * [prefix] - the import prefix, maybe `null`.
 * [element] - the referenced element.
 * [importElementsMap] - the cache of [Element]s imported by [ImportElement]s.
 */
ImportElement internal_getImportElement(
    LibraryElement libraryElement,
    String prefix,
    Element element,
    Map<ImportElement, Set<Element>> importElementsMap) {
  // validate Element
  if (element == null) {
    return null;
  }
  if (element.enclosingElement is! CompilationUnitElement) {
    return null;
  }
  LibraryElement usedLibrary = element.library;
  // find ImportElement that imports used library with used prefix
  List<ImportElement> candidates = null;
  for (ImportElement importElement in libraryElement.imports) {
    // required library
    if (importElement.importedLibrary != usedLibrary) {
      continue;
    }
    // required prefix
    PrefixElement prefixElement = importElement.prefix;
    if (prefix == null) {
      if (prefixElement != null) {
        continue;
      }
    } else {
      if (prefixElement == null) {
        continue;
      }
      if (prefix != prefixElement.name) {
        continue;
      }
    }
    // no combinators => only possible candidate
    if (importElement.combinators.length == 0) {
      return importElement;
    }
    // OK, we have candidate
    if (candidates == null) {
      candidates = [];
    }
    candidates.add(importElement);
  }
  // no candidates, probably element is defined in this library
  if (candidates == null) {
    return null;
  }
  // one candidate
  if (candidates.length == 1) {
    return candidates[0];
  }
  // ensure that each ImportElement has set of elements
  for (ImportElement importElement in candidates) {
    if (importElementsMap.containsKey(importElement)) {
      continue;
    }
    Namespace namespace = importElement.namespace;
    Set<Element> elements = new Set.from(namespace.definedNames.values);
    importElementsMap[importElement] = elements;
  }
  // use import namespace to choose correct one
  for (ImportElement importElement in importElementsMap.keys) {
    Set<Element> elements = importElementsMap[importElement];
    if (elements.contains(element)) {
      return importElement;
    }
  }
  // not found
  return null;
}

/**
 * Returns the [ImportElement] that is referenced by [prefixNode] with a
 * [PrefixElement], maybe `null`.
 */
ImportElement internal_getImportElementInfo(SimpleIdentifier prefixNode) {
  // prepare environment
  AstNode parent = prefixNode.parent;
  CompilationUnit unit = prefixNode.thisOrAncestorOfType<CompilationUnit>();
  LibraryElement libraryElement =
      resolutionMap.elementDeclaredByCompilationUnit(unit).library;
  // prepare used element
  Element usedElement = null;
  if (parent is PrefixedIdentifier) {
    PrefixedIdentifier prefixed = parent;
    if (prefixed.prefix == prefixNode) {
      usedElement = prefixed.staticElement;
    }
  }
  if (parent is MethodInvocation) {
    MethodInvocation invocation = parent;
    if (invocation.target == prefixNode) {
      usedElement = invocation.methodName.staticElement;
    }
  }
  // we need used Element
  if (usedElement == null) {
    return null;
  }
  // find ImportElement
  String prefix = prefixNode.name;
  Map<ImportElement, Set<Element>> importElementsMap = {};
  return internal_getImportElement(
      libraryElement, prefix, usedElement, importElementsMap);
}

/**
 * Information about [ImportElement] and place where it is referenced using
 * [PrefixElement].
 */
class ImportElementInfo {
  ImportElement element;
}

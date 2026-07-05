#!/usr/bin/env node
import fs from 'node:fs';
import { parse } from 'parse5';

const file = process.argv[2] || 'examples/sample-output/study_guide.html';
const html = fs.readFileSync(file, 'utf8');
const errors = [];

const allowedMainTags = new Set([
  'a',
  'br',
  'button',
  'code',
  'div',
  'em',
  'footer',
  'h1',
  'h2',
  'h3',
  'li',
  'main',
  'ol',
  'p',
  'pre',
  'section',
  'span',
  'strong',
  'table',
  'tbody',
  'td',
  'th',
  'thead',
  'tr',
  'ul',
]);

const allowedAttrs = new Map([
  ['a', new Set(['href'])],
  ['button', new Set(['type'])],
]);

function attrsOf(node) {
  return node.attrs || [];
}

function isAllowedAttr(tagName, attrName) {
  if (attrName === 'id' || attrName === 'class') return true;
  if (attrName.startsWith('aria-') || attrName.startsWith('data-')) return true;
  return allowedAttrs.get(tagName)?.has(attrName) || false;
}

function isSafeHref(value) {
  const href = value.trim().toLowerCase();
  return (
    href.startsWith('#') ||
    href.startsWith('/') ||
    href.startsWith('./') ||
    href.startsWith('../') ||
    href.startsWith('http://') ||
    href.startsWith('https://') ||
    href.startsWith('mailto:')
  );
}

function walk(node, visitor) {
  visitor(node);
  for (const child of node.childNodes || []) {
    walk(child, visitor);
  }
}

function findFirst(node, predicate) {
  if (predicate(node)) return node;
  for (const child of node.childNodes || []) {
    const found = findFirst(child, predicate);
    if (found) return found;
  }
  return null;
}

if (html.includes('{{')) {
  errors.push(`${file}: contains unreplaced placeholder`);
}

const document = parse(html);

walk(document, (node) => {
  if (!node.tagName) return;

  for (const attr of attrsOf(node)) {
    const name = attr.name.toLowerCase();
    const value = attr.value || '';
    if (name.startsWith('on')) {
      errors.push(`${file}: <${node.tagName}> has inline event handler "${attr.name}"`);
    }
    if ((name === 'href' || name === 'src') && /^\s*(javascript|data):/i.test(value)) {
      errors.push(`${file}: <${node.tagName}> has unsafe ${attr.name} URL`);
    }
  }
});

const main = findFirst(document, (node) => node.tagName === 'main');
if (!main) {
  errors.push(`${file}: missing <main>`);
} else {
  walk(main, (node) => {
    if (!node.tagName) return;
    const tagName = node.tagName.toLowerCase();

    if (!allowedMainTags.has(tagName)) {
      errors.push(`${file}: <${tagName}> is not allowed inside <main>`);
      return;
    }

    for (const attr of attrsOf(node)) {
      const name = attr.name.toLowerCase();
      const value = attr.value || '';

      if (!isAllowedAttr(tagName, name)) {
        errors.push(`${file}: <${tagName}> attribute "${attr.name}" is not allowed`);
      }
      if (name === 'href' && !isSafeHref(value)) {
        errors.push(`${file}: <a> has unsupported href "${value}"`);
      }
    }
  });
}

if (errors.length > 0) {
  for (const error of errors) {
    console.error(error);
  }
  process.exit(1);
}

console.log(`${file}: generated HTML safety validation passed`);

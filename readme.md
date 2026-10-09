<div align="center">
	<br>
	<br>
	<picture>
		<source media="(prefers-color-scheme: dark)" srcset="media/logo-dark.svg?x2">
		<img height="500" src="media/logo.svg" alt="SOML">
	</picture>
	<br>
	<br>
</div>

> A config format for humans\
> SOML is short for Sindre's Objectively Marvelous Language.

<br>

SOML is a config format that is pleasant to write and easy to read. The top level needs no braces, keys need no quotes, line breaks replace commas, and comments go almost anywhere. A value's type comes from its syntax, never from its content, so what you see is what you get: `'123'` is a string and `123` is an int. Durations like `30s` and dates like `2026-09-19T14:00:00Z` are real values, so nobody has to guess the unit of `timeout: 30`. Paths and regexes need no escaping, and prose goes in block strings. One canonical form and a shared conformance suite mean every implementation reads your file the same way. JSON has the strictness but not the comfort: quotes, commas, and braces everywhere, and no comments. YAML has the comfort but not the clarity: `-` list markers, nested indentation, and types guessed from content, so `country: no` becomes `false` and `version: 3.10` becomes `3.1`. SOML gives you the comfort and the strictness, without the guessing.

<br>

> [!WARNING]
> Work in progress

<br>

```
name: 'api-gateway'
port: 8080 # The load balancer expects this port.
timeout: 30s
windows-path: 'C:\Users\sindre\dev'
description:
	'''
	Terminates TLS.
	Routes requests to internal services.
	'''
allowed-origins: [
	'https://example.com'
	'https://example.org'
]
```

The same in JSON:

```json
{
	"name": "api-gateway",
	"port": 8080,
	"timeout": 30,
	"windows-path": "C:\\Users\\sindre\\dev",
	"description": "Terminates TLS.\nRoutes requests to internal services.",
	"allowed-origins": [
		"https://example.com",
		"https://example.org"
	]
}
```

## Objectives

SOML is a data format for files that people write and read. It is JSON without the noise: keys need no quotes, line breaks replace commas, the top level needs no braces, and comments are allowed. It keeps JSON's tree of objects and arrays and its strictness, and adds literal strings, block strings, dates, and durations.

Its design rests on one rule: **a value's type comes from its syntax, never from its content.** `'123'` is a string and `123` is an int. Nothing is ever retyped by inspecting it.

## Why SOML

- **Less noise than JSON, and comments.** Keys need no quotes, even with dashes, a line break replaces a comma, and the top level needs no braces. Comments are allowed wherever whitespace may go.
- **What you see is the type.** A string always has quotes, and a value without quotes must be a number, an instant, a duration, or a keyword, or the file has an error. So `country: no` is an error rather than `false`, and `'10.20'` and `10.20` are a string and a float, exactly as written.
- **Strict where JSON is vague.** Duplicate keys, lone surrogates, and numbers out of range are errors, not behavior that each parser decides. An int is exact to 64 bits, and `3` and `3.0` stay different types.
- **Pleasant to write.** Literal strings for paths and regexes, and dedented block strings.
- **Dates and durations are values.** `2026-09-19T14:00:00Z` is an instant and `1h30m` is a duration, so no reader has to parse a string or guess a unit.
- **Indentation is free.** Braces and line breaks give the structure, so tabs, spaces, and copy and paste never change what a file means, except inside a block string, where indentation is text.
- **One canonical form.** Equal values give equal bytes, for hashing, signing, and comparing. The formatter is separate, and it keeps your comments, your member order, and how you spelled each value. Its rules are part of the spec, so every conforming formatter gives the same output for the same file.
- **Small and tested.** The grammar is one pass with no lookahead, and every implementation runs the language-neutral [conformance suite](conformance) of nearly 1000 cases.

## Example

```
/*
Everything SOML can express, in one document. A document may also be a top-level array.
*/

# Keys are bare. Dashes are allowed, so no key needs quotes.
name: 'soml'
release-date: 2026-09-19T14:00:00Z
'the name': 'quotes are the escape hatch, when a key needs spaces'
404: 'and a key may begin with a digit'

# Strings: '...' is literal, "..." is escaped. Use ' by default.
regex: '^\d{4}-\d{2}-\d{2}$'
windows-path: 'C:\Users\sindre\dev'
shell: 'echo "$HOME" | tr -d "\n"'
escaped: "line one\nline two\t\"quoted\"\u{1f600}"

# Block strings are dedented by the closing delimiter's column.
description:
	'''
	A block string keeps its line breaks.
	The leading tab of each line is stripped,
	because the closing delimiter sits at one tab.
	'''

# Numbers: int and float are different types.
replicas: 3
ratio: 0.75
budget: 1_000_000
mask: 0b1010_1100
permissions: 0o644
color: 0xFF8800
flags: 0x00FF
limit: infinity
floor: -infinity

# Booleans and null.
drained: false
owner: null

# Durations: exact, in h, m, s, ms, us, and ns.
retry-after: 1m30s

# Arrays. A comma or a line break separates items.
labels: ['prod', 'eu-west', 'canary']
matrix: [[1, 2], [3, 4]]
mixed: [1, 'two', true, null]

# Objects. The top-level object needs no braces.
pool: {
	min: 2
	max: 16
}

# Records in arrays. Braces are required, and that is deliberate.
maintainers: [
	{name: 'Sindre Sorhus', email: 'sindresorhus@gmail.com'}
	{name: 'Random Person', email: 'person@example.com'}
]

# Line comments, and block comments, wherever whitespace may go.
# Inline objects and one-line braced documents work too:
healthcheck: {path: '/health', interval: 10s, grace: 1.5s}
```

## Comparison with other formats

JSON is unambiguous but noisy to write: the file needs braces around it, every item needs a comma, every key needs quotes, and there are no comments. YAML is pleasant to write but ambiguous to read. SOML keeps JSON's data model and strictness, and also decides what JSON leaves to each implementation. From YAML, it takes comments, multi-line strings, and a top level with no braces or commas, but not implicit typing, significant indentation, aliases, or tags. From TOML, it takes literal strings and the split between int and float, but it allows a top-level array and has no table headers or dotted keys.

| | SOML | JSON | YAML 1.2 | TOML 1.1 |
|---|---|---|---|---|
| Comments | `#` and `/* */` | no | `#` | `#` |
| Braces around a top-level object | no | required | no | no |
| Commas between items on separate lines | no | required | no | required in arrays and inline tables |
| Keys without quotes | yes, dashes and digits included | no | yes | yes |
| A value's type comes from its syntax | yes | yes | no, an unquoted value is typed by its content | yes |
| Separate int and float | yes | no | yes | yes |
| Dates and durations | an instant and a duration | no | no, but many parsers still read dates | four date and time types, no duration |
| Duplicate keys | an error | left to the parser | an error, but some parsers keep the last | an error |
| A top-level array | yes | yes | yes | no |
| Indentation changes the meaning | no | no | yes | no |
| Canonical form | yes | only in a separate scheme, RFC 8785 | for scalars only | no |
| Libraries | new, in a few languages | everywhere | everywhere | most languages |

See the [full comparison](comparison.md) with JSON, JSON5, JSONC, TOML, YAML, and other formats, including where another format is the better choice.

## Specification

The format is defined in the [specification](spec.md), which also gives the reason for each decision. The [FAQ](faq.md) gives short answers to common questions, such as why SOML has durations and separate int and float types.

## Linting

Use [eslint-soml](https://github.com/soml-lang/eslint-soml) with [eslint-plugin-unicorn](https://github.com/sindresorhus/eslint-plugin-unicorn#soml) for additional lint rules. Unicorn provides a `recommended-soml` preset.

<!-- ## Implementations

- [JavaScript](https://github.com/soml-lang/soml-javascript) (the reference implementation)
- [Swift](https://github.com/soml-lang/SOMLSwift)
- [Rust](https://github.com/soml-lang/soml-rust)
- [Python](https://github.com/soml-lang/soml-python)
- [Ruby](https://github.com/soml-lang/soml-ruby)
- [Go](https://github.com/soml-lang/soml-go)
- [C](https://github.com/soml-lang/soml-c)

## Tools

- [CLI](https://github.com/soml-lang/soml-cli) (check, format, edit, and convert documents)
- [ESLint plugin](https://github.com/soml-lang/eslint-soml)
- [Prettier plugin](https://github.com/soml-lang/prettier-plugin-soml)
- [Visual Studio Code](https://github.com/soml-lang/vscode-soml) (the TextMate grammar also works in JetBrains IDEs and Shiki)
- [Sublime Text](https://github.com/soml-lang/sublime-soml)
- [Zed](https://github.com/soml-lang/zed-soml)
- [tree-sitter](https://github.com/soml-lang/tree-sitter-soml)
- [swift-configuration](https://github.com/soml-lang/swift-configuration-soml) (a provider for Apple's configuration library)
-->

## License

The [MIT license](license) applies to the specification itself. You may freely implement this specification without including or referencing the license.

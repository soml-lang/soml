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
> Draft spec. Feedback welcome.

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

SOML is a data format for files that people write and read. It is JSON without the noise, and with comments. It keeps JSON's tree of objects and arrays and its strictness, and adds literal strings, block strings, dates, and durations.

Its design rests on one rule: **a value's type comes from its syntax, never from its content.** `'123'` is a string and `123` is an int. Nothing is ever retyped by inspecting it.

## Why SOML

- **Less noise than JSON, and comments.** Keys need no quotes, even with dashes, a line break replaces a comma, and the top level needs no braces. Comments are allowed wherever whitespace may go.
- **What you see is the type.** A string always has quotes, and a value without quotes must be a number, an instant, a duration, or a keyword, or the file has an error. So `country: no` is an error rather than `false`, and `'10.20'` and `10.20` are a string and a float, exactly as written.
- **Strict where JSON is vague.** Duplicate keys, lone surrogates, and numbers out of range are errors, not behavior that each parser decides. An int is exact to 64 bits, and `3` and `3.0` stay different types.
- **Pleasant to write.** Literal strings, so paths and regexes need no escaping, and dedented block strings for prose.
- **Dates and durations are values.** `2026-09-19T14:00:00Z` is an instant and `1h30m` is a duration, so no reader has to parse a string or guess a unit.
- **Indentation is free.** Braces and line breaks give the structure, so tabs, spaces, and copy and paste never change what a file means, except inside a block string, where indentation is text.
- **One canonical form.** Equal values give equal bytes, for hashing, signing, and comparing. A separate formatter keeps your comments, member order, and the spelling of each value. Its rules are part of the spec, so every conforming formatter gives the same output for the same file.
- **Small and tested.** The grammar is one pass with no lookahead, and every implementation runs the language-neutral [conformance suite](conformance) of nearly 1000 cases, so every implementation reads a file the same way.

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

## Why not YAML?

SOML keeps what I like about YAML: comments, no braces around the file, no commas at the ends of lines, and keys without quotes. It removes what hurts: in YAML, the content of a value decides its type. In SOML, the syntax decides, so `'no'` is a string, `3.10` is a float, and `2` is an int, in every implementation.

What SOML adds:

- Block comments with `/* */`, in addition to `#`.
- Durations such as `30s` and `1h30m`, so `timeout: 30` no longer makes the reader guess the unit.
- Instants such as `2026-09-19T14:00:00Z`. YAML 1.2 dropped timestamps, but many parsers still read them, so a date in YAML may or may not be a string.
- A canonical form, so equal values give equal bytes for hashing and signing. YAML defines one for scalars only.
- A formatter whose rules are part of the spec. It keeps your comments, key order, and the spelling of each value. YAML says comments are not content, so tools may drop them.
- Editing rules, so a tool can change one value and keep the comments and layout of the rest.
- Error messages that usually say what to write instead.

What SOML fixes:

- **Values change type without warning.** In PyYAML (YAML 1.1), `country: no` is `false`, `zip: 01234` is octal 668, and `time: 22:22` is base-60 1342. YAML 1.2 fixed those, but most of the ecosystem still follows 1.1, and 1.2 still guesses: `version: 3.10` is the float `3.1`, and `~`, `Null`, and an empty value are null. SOML strings always have quotes, so `country: no` is an error.
- **Keys are not always strings.** `1: x` gives an integer key in YAML, and PyYAML reads `on: x` as the boolean `true`. SOML keys are always strings, so `404:` is the key `'404'`.
- **Indentation is the structure.** One space too few moves a key into another object, and the file still parses, which is why YAML forbids tabs there. SOML gets its structure from braces and line breaks, so indentation only helps the reader, except in a block string, where it is text.
- **Block strings add a newline.** YAML's default `|` keeps a trailing `\n` in the value; SOML does not.
- **Large ints lose precision.** js-yaml turns `id: 9007199254740993` into `9007199254740992`. A SOML int is an exact int64; a larger one is an error.
- **Duplicate keys go unnoticed.** For `a: 1` then `a: 2`, PyYAML keeps `2` and says nothing. The spec forbids duplicates, but after type resolution `1:` and `01:` may or may not collide, depending on the schema. SOML compares the decoded strings and reports each duplicate.
- **A missing value is null.** `timeout:` with no value is null in YAML, and a file with only comments is null in PyYAML. SOML rejects both, so a forgotten value cannot pass as a default.
- **The language is large.** YAML has two syntaxes for every list and map, two block string styles with three newline rules, indentation indicators, anchors, aliases, tags, multiple documents per file, three processing stages, and three recommended schemas. SOML has one syntax for each, one block string style, and one set of type rules.
- **Parsers disagree.** In the YAML test matrix (newest snapshot 2022), PyYAML fails 73 of 402 cases. `2024-01-01` is a date in PyYAML and a string in js-yaml 5, and `1_000` is `1000` in PyYAML and a string in js-yaml. SOML implementations share one [conformance suite](conformance) of nearly 1000 cases.
- **Two features are a security risk.** Aliases make YAML bombs possible: a small file expands into billions of nodes. Tags let a loader construct objects, and PyYAML has had four remote code execution CVEs rated 9.8. `safe_load` is opt-in, and even a loader named “safe” can turn aliases on. SOML has neither, one way to load, and limits on nesting and ranges.

## Why not TOML?

SOML keeps what TOML gets right: predictable types, literal strings, insignificant indentation, and duplicate keys as errors. It removes what hurts: table rules where a key's meaning depends on what came before it, and values that parsers silently round, truncate, or read differently. A SOML file means one thing, no matter where a line sits or which parser reads it.

What SOML adds:

- Top-level arrays. A TOML file is always a table, so a list of records needs a wrapper key.
- Block comments with `/* */`, in addition to `#`.
- Line breaks in place of commas, so a multi-line array needs none.
- Durations such as `30s` and `1h30m`, so `timeout = 30` no longer makes the reader guess the unit.
- One instant type in place of four date and time types, three of which are not points in time.
- A canonical form, so equal values give equal bytes for hashing and signing.
- A formatter whose rules are part of the spec, so every conforming formatter gives the same output.

What SOML fixes:

- **Three ways to nest.** `[server]` with `port = 8080`, `server.port = 8080`, and `server = {port = 8080}` all give the same table, each with its own rules. Projects mix them, often in one file. SOML has one way: braces.
- **Later lines can change earlier tables.** Even at the end of a file, `[[users]]` adds to an earlier array, `[server.tls]` to an earlier table, and a bare key to the last table. An attacker who can put a newline into one value can add a user with `role = 'admin'`, as CVE-2026-44244 injected a `[core]` section into `.git/config` for code execution. BurntSushi/toml even lets a later `users = ['mallory']` under `[auth]` silently replace an earlier `[auth.users.alice]` table. In SOML, earlier objects and arrays are closed.
- **Table headers have hidden scope.** `[server]` moves every following key into `server`, even `timeout = 30`, with no way back to the root. SOML braces make boundaries explicit.
- **Dotted paths behave differently from headers.** Inside `[server]`, `logging.level = 'debug'` is `server.logging.level`, but `[logging]` is a root table, and `server.port = 8080` is `server.server.port`. In SOML, a key belongs to the braces around it.
- **Extension rules depend on how a table was made.** `[a.b]` then `[a]` is valid, but `a.b.c = 1` then `[a]` is not. Header and dotted-key tables can be extended, inline tables cannot, and `[[servers]]` can append to an array of tables, but not to `servers = []`. SOML has no implicit tables, and one syntax each for objects and arrays.
- **Arrays of tables depend on order.** `[servers.tls]` attaches to the most recent `[[servers]]`, so moving a section can silently attach it to another server. SOML array elements are self-contained objects.
- **Dotted keys silently change structure.** `3.14 = 'pi'`, `example.com`, and `tls.crt` are nested keys, and `servers.0.port` creates the key `'0'`, not an array element. SOML needs quotes for a literal dot.
- **Renaming requires chasing paths.** Headers such as `[server.database]` and `[server.cache]` repeat the parent name, so a rename that misses one silently creates a separate object. SOML names the parent once.
- **Reindentation changes strings.** Multiline strings keep their indentation and the newline before the closing delimiter, and newline normalization is platform-dependent. SOML dedents block strings, adds no trailing newline, and requires LF.
- **No `null`, but `nan`.** TOML cannot tell an explicit null from a missing key, so writers must drop it or fail: `@iarna/toml` silently drops a `null` value, and Python's `toml` turns `None` in an array into the string `'None'`. TOML has `nan`. SOML has `null`, and no `nan`, which is not equal to itself.
- **Numbers and times change between parsers.** `1e999` is infinity in Python's `tomllib` and smol-toml, but an error in Go and Rust, and `1e-400` is zero in all of them. `.123456789` seconds is exact in Go and Rust, `.123456` in `tomllib`, and `.123` in smol-toml. `9223372036854775808` works in `tomllib` but not in Rust's `toml`. SOML ints are exact int64, instants keep nanoseconds, and a float that does not fit is an error.
- **Broken input passes.** TOML reads an empty or comment-only file as an empty table, permits replacing malformed UTF-8 with `U+FFFD`, and leaves BOM handling unspecified. SOML rejects all of these, so an emptied config cannot fall back to defaults.
- **JSON must be rewritten.** TOML uses `=`, so a JSON object cannot be pasted in, not even as a value. SOML uses `:`, so hand-written JSON is usually valid SOML, and the syntax is already familiar from JSON, YAML, and JavaScript.

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

## Implementations

- [JavaScript](https://github.com/soml-lang/soml-javascript) (the reference implementation)
- [Swift](https://github.com/soml-lang/SOMLSwift)
- [Rust](https://github.com/soml-lang/soml-rust)
- [Python](https://github.com/soml-lang/soml-python)
- [Go](https://github.com/soml-lang/soml-go)
- [Ruby](https://github.com/soml-lang/soml-ruby)
- [C++](https://github.com/soml-lang/soml-cplusplus)
- [C](https://github.com/soml-lang/soml-c)
- [Java](https://github.com/soml-lang/soml-java)
- [Dart](https://github.com/soml-lang/soml-dart)
- [PHP](https://github.com/soml-lang/soml-php)
- [Zsh](https://github.com/soml-lang/soml-zsh)

## Tools

- [ESLint plugin](https://github.com/soml-lang/eslint-soml)
- [Prettier plugin](https://github.com/soml-lang/prettier-plugin-soml)
- [highlight.js syntax highlighting](https://github.com/soml-lang/highlightjs-soml)
- [Prism syntax highlighting](https://github.com/PrismJS/prism/pull/4187) *(👍 the PR to show your support)*

## Editor plugins

- [Visual Studio Code](https://github.com/soml-lang/vscode-soml)
- [Sublime Text](https://github.com/soml-lang/sublime-soml)
- [TextMate](https://github.com/soml-lang/textmate-soml)

## Apps

- [SOML Editor](https://sindresorhus.com/soml-editor) - macOS app to view and edit SOML files and Quick Look support

## Linting

Use [eslint-soml](https://github.com/soml-lang/eslint-soml) with [eslint-plugin-unicorn](https://github.com/sindresorhus/eslint-plugin-unicorn#soml) for additional lint rules. Unicorn provides a `recommended-soml` preset.

## License

The [MIT license](license) applies to the specification itself. You may freely implement this specification without including or referencing the license.

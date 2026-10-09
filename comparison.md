# How SOML compares

This document compares SOML with JSON, JSON5, JSONC, TOML, YAML, and other formats. The format itself is defined in [spec.md](spec.md).

Every format here made a reasonable choice for its own goal, and most of SOML is borrowed from them. The case for SOML is first that it is JSON without the noise: the top level needs no braces, line breaks replace commas, keys need no quotes, and comments are allowed. It keeps JSON's data model and strictness, takes more authoring comfort from YAML and TOML, and decides every case that the others leave to each parser. Most claims below quote their source, and the last section says when another format is the better choice.

## At a glance

| | SOML | JSON | JSON5 | YAML 1.2 | TOML 1.1 |
|---|---|---|---|---|---|
| Comments | `#` and `/* */` | no | `//` and `/* */` | `#` | `#` |
| Braces around a top-level object | no | required | required | no | no |
| Commas between items on separate lines | no | required | required | no | required in arrays and inline tables |
| Keys without quotes | yes, dashes and digits included | no | identifiers only, so not `content-type` | yes | yes |
| A value's type comes from its syntax | yes | yes | yes | no, an unquoted value is typed by its content | yes |
| Separate int and float | yes | no | no | yes | yes |
| Literal strings for paths and regexes | yes | no | no | yes | yes |
| Dates and durations | an instant and a duration | no | no | no, but many parsers still read dates | four date and time types, no duration |
| Duplicate keys | an error | left to the parser | left to the parser | an error, but some parsers keep the last | an error |
| A top-level array | yes | yes | yes | yes | no |
| Indentation changes the meaning | no | no | no | yes | no |
| Aliases and tags | no | no | no | yes | no |
| More than one document per file | no | no | no | yes | no |
| Canonical form | yes | only in a separate scheme, RFC 8785 | no | for scalars only | no |
| Libraries | new, in a few languages | everywhere | many, centred on JavaScript | everywhere | most languages |


## What JSON does not give you

| | JSON | SOML |
|---|---|---|
| The top level | `{` and `}` around the whole file | no braces, so members start at column 0 |
| Commas | required, and a trailing one is forbidden | a line break separates items, and a trailing comma is allowed |
| Keys | `"always": "quoted"` | `bare-key:`, dashes allowed, never coerced |
| Comments | none, ever | `#` and `/* */`, wherever whitespace may go |
| Strings with backslashes | `"C:\\Users\\sindre\\dev"` | `'C:\Users\sindre\dev'`, literal |
| Prose | `"one\ntwo\nthree"` | `'''` block strings, dedented automatically |
| An int and a float | one `number` type | `3` and `3.0` are different types |
| Integers | decimal only | `1_000_000`, `0xFF`, `0o644`, `0b1010` |
| Infinity | not permitted | `infinity`, `-infinity` |
| A date | a string every reader re-parses | `2026-09-19T14:00:00Z`, a real type |
| A duration | a number in a unit the reader must guess | `30s`, `1h30m`, a real type |
| Duplicate keys | undefined, and implementations differ | an error |
| A number past 2^53 | exact in some parsers, and a wrong value, silently, in others | int64, or an error |
| A lone surrogate | several outcomes, none of them reported | an error |
| Line endings and a BOM | CRLF is valid, and a BOM is left to the parser | LF only, and no BOM |
| Bytes you can compare | whatever the writer felt like | one canonical form |

No top-level braces, optional commas, bare keys, and comments are the main reason SOML exists, together with literal strings and block strings, because they make a file pleasant to write rather than merely correct. Of the other rows, some are things JSON cannot express at all, and some are things it deliberately leaves to the implementation, which in practice means each implementation decides differently.

## What that costs in practice

None of this is theoretical. Each item below is a measured disagreement between mainstream implementations of the same format, or a statement from a specification about its own gap.

- **A duplicate key resolves several different ways, and that has been exploited.** Apache CouchDB's CVE-2017-12635 let any user grant themselves administrative rights: the JavaScript parser that authorised the write used the second `roles` key, and the Erlang parser that governed later authorisation used the first. Python and ECMAScript keep the last value, Go's original `encoding/json` replaces or merges depending on the target type, while `encoding/json/v2`, new in Go 1.27, rejects a duplicate, and a 2021 survey of 49 parsers found 7 that keep the first. ECMAScript's rule is that "lexically preceding values for the same key shall be overwritten", and that collapse happens before any reviver runs, so a duplicate cannot be detected after parsing.
- **A lone surrogate has three outcomes.** `"\uD800"` survives exactly in Python and Node, becomes U+FFFD with no error in Go's original `encoding/json`, and is rejected outright by PHP, Ruby, and Go's `encoding/json/v2`. In the original Go package, `"\uD800"` and `"�"` then collapse into the same string. RFC 8259 §8.2 permits this, describes the exact bug class, and declines to forbid it.
- **An integer past 2^53 is wrong, silently.** `9007199254740993` is exact in Python, and becomes `9007199254740992` in JavaScript. Neither side reports anything. X and Discord both work around this by shipping 64-bit IDs as strings, and Protobuf's JSON mapping does the same.
- **NaN has four behaviours.** Python emits `NaN` by default, which is invalid JSON and documented as non-compliant. JavaScript turns it into `null`, which makes a NaN indistinguishable from a null. Go refuses to encode it, and PHP returns `false` with no warning or exception, unless `JSON_THROW_ON_ERROR` is passed.
- **One vendor ships two JSON parsers with opposite defaults, and the difference is barely documented.** .NET's configuration documentation covers comment support but says nothing about trailing commas, which the configuration parser accepts and the general serializer rejects. So one file can be accepted by your editor, accepted by your runtime, and rejected by your linter, and the format's own draft admits why: trailing commas "are not a requirement" because the reference implementation disables them by default. The JSONC section below has the full picture.

JSON is not broken. It deliberately leaves several interoperability-relevant semantics to the implementation, and every implementation filled those gaps in a different direction. The gaps are all in one place: **what a value means.** SOML decides all of it.

## The same file in each format

A real service config, first in SOML, then in JSON, JSON5, YAML, and TOML. JSONC is the JSON file with comments.

**SOML**

```
# The edge service. See the runbook before you touch this.
name: 'api-gateway'
version: '2.1.0'
pattern: '^\d{4}-\d{2}-\d{2}$'
windows-path: 'C:\Users\sindre\dev'
content-security-policy: "default-src 'self'; script-src https://cdn.example.com"
replicas: 3
timeout: 30s
drained: false
owner: null
deployed-at: 2026-09-19T14:00:00Z
labels: ['prod', 'eu-west', 'canary']
description:
	'''
	The API gateway terminates TLS.
	It routes requests to internal services.
	It has no external dependencies.
	'''
postgres: {
	host: 'db.internal'
	port: 5432
	ssl: true
}
```

**JSON**

```json
{
	"name": "api-gateway",
	"version": "2.1.0",
	"pattern": "^\\d{4}-\\d{2}-\\d{2}$",
	"windows-path": "C:\\Users\\sindre\\dev",
	"content-security-policy": "default-src 'self'; script-src https://cdn.example.com",
	"replicas": 3,
	"timeout": 30.0,
	"drained": false,
	"owner": null,
	"deployed-at": "2026-09-19T14:00:00Z",
	"labels": ["prod", "eu-west", "canary"],
	"description": "The API gateway terminates TLS.\nIt routes requests to internal services.\nIt has no external dependencies.",
	"postgres": {
		"host": "db.internal",
		"port": 5432,
		"ssl": true
	}
}
```

**JSON5**

```json5
// The edge service. See the runbook before you touch this.
{
	name: 'api-gateway',
	version: '2.1.0',
	pattern: '^\\d{4}-\\d{2}-\\d{2}$',
	'windows-path': 'C:\\Users\\sindre\\dev',
	'content-security-policy': "default-src 'self'; script-src https://cdn.example.com",
	replicas: 3,
	timeout: 30.0,
	drained: false,
	owner: null,
	'deployed-at': '2026-09-19T14:00:00Z',
	labels: ['prod', 'eu-west', 'canary'],
	description: 'The API gateway terminates TLS.\nIt routes requests to internal services.\nIt has no external dependencies.',
	postgres: {
		host: 'db.internal',
		port: 5432,
		ssl: true,
	},
}
```

**YAML**

```yaml
# The edge service. See the runbook before you touch this.
name: api-gateway
version: 2.1.0
pattern: '^\d{4}-\d{2}-\d{2}$'
windows-path: 'C:\Users\sindre\dev'
content-security-policy: "default-src 'self'; script-src https://cdn.example.com"
replicas: 3
timeout: 30.0
drained: false
owner: null
deployed-at: 2026-09-19T14:00:00Z
labels: [prod, eu-west, canary]
description: |-
  The API gateway terminates TLS.
  It routes requests to internal services.
  It has no external dependencies.
postgres:
  host: db.internal
  port: 5432
  ssl: true
```

**TOML**

```toml
# The edge service. See the runbook before you touch this.
name = "api-gateway"
version = "2.1.0"
pattern = '^\d{4}-\d{2}-\d{2}$'
windows-path = 'C:\Users\sindre\dev'
content-security-policy = "default-src 'self'; script-src https://cdn.example.com"
replicas = 3
timeout = 30.0
drained = false
# TOML has no null, so `owner` is left out.
deployed-at = 2026-09-19T14:00:00Z
labels = ["prod", "eu-west", "canary"]
description = """
The API gateway terminates TLS.
It routes requests to internal services.
It has no external dependencies."""

[postgres]
host = "db.internal"
port = 5432
ssl = true
```

Against JSON, the differences are the whole format:

- **The outer braces go.** The top level needs no `{` and `}`, so its members start at column 0, and the whole file is one level shallower.
- **The commas are optional.** A line break separates items, at the top level and inside `[]` and `{}`, so you add a line to the end of a list without touching the line before it, and a diff is one line instead of two.
- **The keys stop shouting.** No common key needs quotes, and a hyphenated key does not either, because a bare key allows dashes. Only a key with a space, a dot, or a character outside letters, digits, `_`, and `-` needs quotes.
- **Comments exist.** JSON has none, at all, ever.
- **The backslashes disappear.** In JSON, `C:\\Users\\sindre\\dev` and `^\\d{4}` double every backslash, because `\` is always an escape. In SOML, `'...'` is literal, so a Windows path and a regex are written exactly as they are.
- **The apostrophes stop fighting the quotes.** The CSP header contains `'self'`, so it uses `"..."`. The rule is one sentence: use `'` by default, and switch to `"` when the content contains a `'` or a character that needs an escape.
- **Prose becomes writable.** JSON forces `\n` in the middle of a paragraph. SOML uses a block string that is dedented automatically.
- **A date becomes a date.** `2026-09-19T14:00:00Z` is a value of type `instant`, not a string that every consumer must re-parse.
- **A duration has a unit.** `30.0` leaves the reader to guess seconds or milliseconds, and `30s` does not.
- **A key stays a key.** `postgres` is an object in braces, as in JSON, without the quotes and commas. A `.` never turns a key into a path, so a host name or a package name used as a key cannot become nested objects by accident.

The other formats each fix part of this:

- **JSON5** adds comments, bare keys, and trailing commas, but keeps the braces and a comma after every member. A key with a dash still needs quotes, every backslash is still doubled, and prose still needs `\n`.
- **YAML** is as quiet as SOML, but nothing in it marks a string. `deployed-at` is a date in PyYAML and a string in parsers that follow YAML 1.2, and a version such as `10.23` would be a float. Indentation is the structure, and `|-` is one of six block-string styles.
- **TOML** is also quiet, but it has no null, so `owner` cannot be written. A key after the `[postgres]` header belongs to that table, so the header must come last.

## vs JSON

JSON is the baseline. SOML keeps its data model, its strictness, and its one-pass grammar. What SOML changes is first the noise, so the top level needs no braces, commas are optional, keys need no quotes, and comments are allowed, and then the list of things JSON never decided.

**JSON's own documents describe the gap.** RFC 8259 §1.3 states its purpose as "to apply the errata, remove inconsistencies with other specifications of JSON, and highlight practices that can lead to interoperability problems". §1.2 then notes that ECMA-404 "allows several practices that this specification recommends avoiding in the interests of maximal interoperability". The RFC is a warning label attached to its own format.

**The two co-normative specifications disagree on duplicate keys, and neither resolves it.** RFC 8259 §4: "The names within an object SHOULD be unique." ECMA-404 §6: the syntax "does not require that name strings be unique, and does not assign any significance to the ordering of name/value pairs." ECMA-404 also states that the semantic restrictions in RFC 8259 "are not normative for this specification", so the RFC's SHOULD carries no force there. A correction request against the discrepancy was filed in 2025 and rejected the next day.

**RFC 8259 grants a licence to be lossy.** From §6:

> "This specification allows implementations to set limits on the range and precision of numbers accepted. ... good interoperability can be achieved by implementations that expect no more precision or range than these provide, in the sense that implementations will approximate JSON numbers within the expected precision."
> "Note that when such software is used, numbers that are integers and are in the range [-(2\*\*53)+1, (2\*\*53)-1] are interoperable..."

"Implementations will approximate" means a silently wrong number is conformant. §9 repeats the licence for parsers. §10 then requires that generators "MUST strictly conform". Permissive in, strict out, which is why the defects survive.

**§8.2 permits lone surrogates and names the failure:**

> "the ABNF in this specification allows member names and string values to contain bit sequences that cannot encode Unicode characters; for example, `"\uDEAD"` (a single unpaired UTF-16 surrogate). ... The behavior of software that receives JSON texts containing such values is unpredictable; for example, implementations might return different values for the length of a string value or even suffer fatal runtime exceptions."

**Comments** have no production at all. The sentence every JSON superset stands on is in §9: "A JSON parser MAY accept non-JSON forms or extensions." That is a licence rather than an invitation, because ECMA-404 says a conforming processor "should not accept any inputs that are not conforming JSON texts".

| Defect | RFC 8259 | SOML |
|---|---|---|
| Duplicate keys | "SHOULD be unique", behaviour "unpredictable", contradicted by ECMA-404 | error |
| Lone surrogates | permitted; §8.2 warns and declines | error |
| Integers past 2^53 | permitted; "implementations will approximate" | int64 or error |
| Comments | no production; parsers MAY extend | `#` and `/* */` |
| Top-level braces | required around an object | none |
| Commas | required, and a trailing one is forbidden | optional across lines, and a trailing one is allowed |
| int vs float | one `number` production; ECMA-404: "JSON is agnostic about the semantics of numbers" | distinct types |
| Date and time | no production | `instant` |
| Duration | no production | `duration` |
| Infinity | "are not permitted" | `infinity`, `-infinity` |
| BOM | MUST NOT be emitted in transmitted text, MAY be ignored on read | error |
| `\/` | permitted, with no rule for which form to emit | no `\/` |
| Canonical form | none | defined |

**Why not profile JSON instead, the way I-JSON did?** Because I-JSON already exists and shows the ceiling. RFC 7493 defines "a restricted profile of JSON designed to maximize interoperability", and it fixes exactly three of the items above: duplicate names (§2.3, "MUST NOT"), lone surrogates (§2.1, "MUST NOT include code points that identify Surrogates or Noncharacters"), and precision (§2.2, "SHOULD NOT include numbers that express greater magnitude or precision than an IEEE 754 double"). Its goal statement is a good description of the problem:

> "For historical reasons, that specification allows the use of language idioms and text encoding patterns that are likely to lead to interoperability problems and software breakage, particularly when a program receiving JSON data uses automated software to map it into native programming-language structures or database records."

It could not go further, because **a profile cannot change a grammar.** I-JSON cannot add a comment, drop the top-level braces or a comma, separate an int from a float, or promote its recommended timestamp convention to a type. Those are syntax, and syntax is what SOML changes.

**And JSON should not change.** ECMA-404 makes the case for freezing it: "Because it is so simple, it is not expected that the JSON grammar will ever change. This gives JSON, as a foundational notation, tremendous stability." That is a good argument. It is also the reason the fixes have to live somewhere else.

## vs JSON5

JSON5 is SOML's most widely used neighbour and the most successful attempt to fix JSON's authoring pain. Chrome DevTools, Next.js, Babel, Xcode, and Apple's `plutil` and `swift-foundation` use it, and its npm package sees roughly 290 million downloads a week, as of October 2026. Next.js says why: "We load JSON contents with JSON5 to allow users to comment in their configuration file."

**What JSON5 gets right, and SOML keeps:** unquoted keys, line and block comments, trailing commas, and no implicit typing.

**What JSON5 leaves broken.** It changes syntax and nothing else. It keeps JSON's weak duplicate-key wording, "The names within an object should be unique", and "the behavior of software that receives such an object is unpredictable". It says nothing about lone surrogates, and it has one number type and no date type.

**It has no canonical form.** `+1` and `1`, `.5` and `0.5`, `0x10` and `16`, `Infinity` and `+Infinity`, and `\x00` and `\0` are each one value, and a JSON5 generator has no rule for which to emit. So two generators can give different bytes for one value.

**Four specific improvements over JSON5.**

1. **No top-level braces, and no commas between lines.** A JSON5 document is still wrapped in `{}`, and every member still needs a comma, so only a trailing one is optional. In SOML, the top level has no braces, and a line break separates items, so adding a line never touches the line before it.
2. **Hyphenated keys need no quotes.** A JSON5 unquoted key must be an ECMAScript identifier, which excludes `-`, and the specification's own example quotes `'aspect-ratio'`. So `content-type`, `x-forwarded-for`, and every CLI flag stay quoted.
3. **Single quotes are literal.** In JSON5, a backslash before a character that is not an escape is deleted, and the specification's own example is `'\A\C\/\D\C'`, which equals `'AC/DC'`. So `'C:\Users\sindre'` silently reads as `C:Userssindre`. In SOML, `'...'` is literal, so a Windows path and a regex are written exactly as they are.
4. **Invisible characters are not whitespace.** JSON5 accepts U+FEFF anywhere, U+00A0, U+2028, U+2029, and the whole Unicode Zs category as whitespace. SOML permits exactly three whitespace characters and rejects the rest.

**Where SOML is deliberately smaller.** JSON5 also adds `\v`, `\0`, `\xHH`, the `+` sign, leading and trailing decimal points, and six spellings of the special floats (`Infinity`, `+Infinity`, `-Infinity`, `NaN`, `+NaN`, `-NaN`). Every one of those is a second spelling for a value that already has one. SOML admits several spellings too, but it defines which of them a generator emits, and that is the difference that matters for diffs and hashes.

**JSON5's own standing is weak.** Its abstract still says "proposed", although the document is labelled a standard at 1.0.0. It has no IANA media type, and has had no substantive change since March 2018. That is workable for a superset people use through implementations, but it means JSON5 is not where JSON's semantic defects will ever be fixed.

## vs JSONC

JSONC is JSON with comments, and nothing else. A file still needs braces around the top level, quotes around every key, and a comma between every two items. Its history also shows why "just add comments" is not a design.

**It is not a standard, and its own draft says so.** "Notice: This is a draft of the JSONC Specification and is subject to change." Its stated goal is to "formalize the JSONC format as what `jsonc-parser` considers valid while using its default configurations." A specification written to match one parser's defaults, rather than the reverse, is the whole story. A VS Code maintainer stated it plainly in 2020: "JSONC is not a standard."

**Trailing commas are not in the format.** The ABNF says so in a comment: `; - Trailing commas are NOT supported in this grammar.` The prose is permissive rather than normative: "JSONC parsers MAY support trailing commas." Appendix A explains why:

> "Trailing commas are not a requirement because the reference implementation, `jsonc-parser`, does not allow them unless explicitly configured. The `allowTrailingComma` option is set to `false` by default, so any trailing comma will result in a parsing error."

**The maintainer explained what that costs.** From a 2020 VS Code issue that asked to tolerate trailing commas, where the maintainer explained the earlier change to warn:

> "JSONC is not a standard, but there are several tools that use JSON with comment such as eslint and tsconfig. However, some of them don't accept the trailing commas. The editor would not complain and users would only find out at runtime that there's a trailing comma. After multiple complaints we changed the default to warn."

A file your editor accepts and your runtime rejects is precisely the failure SOML exists to prevent.

**The ecosystem is split, and not along a clean line.** Comments are near-universal. Trailing commas are contested even among tools that accept comments:

| Consumer | Comments | Trailing commas |
|---|---|---|
| VS Code `settings.json` | yes | allowed by its schema |
| TypeScript `tsconfig.json` | yes | accepted |
| .NET `appsettings.json` | yes | accepted |
| .NET `JsonSerializer` | error | error |
| ARM templates | yes | undocumented |
| Neovim `.jsonc` | yes | error |
| JetBrains `.jsonc` | yes | flagged by an inspection |
| Node.js config | error | error |

Read rows 3 and 4 together. The same vendor's same JSON stack accepts both features in configuration files and rejects them by default everywhere else, and the trailing-comma tolerance is not documented. The dialect is decided by whichever parser instance you reach.

**`tsconfig.json` is not JSONC at all.** It accepts trailing commas, both comment styles, hex numbers, a leading decimal point, a BOM, and duplicate keys with no diagnostic, because TypeScript runs its JavaScript parser over the file and validates the result afterwards. The TSConfig documentation says none of this.

**JSONC changes nothing about meaning.** Its entire validation surface is syntax errors. The reference parser's `ParseErrorCode` enumeration has no entry for a duplicate key, a lone surrogate, or a date, and none for a number it cannot represent, so `1e999` becomes `Infinity` with an empty error list. A duplicate key returns `{"a": 2}` with an empty error list, and a number past 2^53 returns the wrong value with an empty error list.

**Java's new JSON API declined the whole approach**, and its reasoning deserves an answer rather than a dismissal. From JEP 540:

> "Syntax extensions such as trailing commas and comments are not supported. ... This policy, permitted by the RFC, provides maximum interoperability and predictability, and reduces concerns about processing malformed or ambiguous JSON documents."

> "Given our focus on simplicity and machine-to-machine communication, we do not support such extensions. Doing so would enlarge the testing matrix, increase the possibility of interoperability errors, and increase the overall development and maintenance burden."

That objection is correct as long as comments and trailing commas are *extensions*. In SOML they are the format: specified once, accepted by every parser, and never changed by a configuration flag. JSONC cannot offer conformance, because there is nothing to conform to.

## vs TOML

TOML is the closest thing in this document to a correct answer, and SOML borrows from it deliberately. It also demonstrates why SOML is shaped the way it is, because TOML's own issue tracker holds complaints its maintainers weighed and mostly declined, plus one that took nearly eight years to ship.

**What SOML takes from TOML:** literal strings (`'...'`) with no escaping, triple-quoted multi-line strings, trailing commas in arrays, hex, octal, and binary integers, underscore digit separators, an explicit int and float split, duplicate keys forbidden, lowercase `true` and `false`, heterogeneous arrays, and indentation that is ignored.

**What TOML gets right and others do not.** It fixed the class of bug that makes YAML dangerous. Types come from literal syntax alone, with no conversion or guessing rules to memorise. `1234` as a key is a string. There is no `yes`, `on`, or `NO` trap.

**Where the two formats part company:**

| | TOML | SOML |
|---|---|---|
| Top-level value | always a hash table | an object or an array; object braces optional |
| Top-level array | not possible | allowed |
| Nesting | table headers, dotted keys, and inline tables | braces |
| Dotted keys | allowed anywhere, and nesting also depends on table headers, which are stateful and order-dependent | none: a `.` in a bare key is an error |
| Temporal types | four, and no duration | an instant and a duration |
| Ways to nest | three (headers, dotted keys, inline tables) | one (braces) |
| A key that looks like a float (`3.14`) | two nested keys, and the spec warns against it | an error, and `'3.14'` is the key |
| Commas in a multi-line array | required between items | optional, a line break separates items |
| Duration type | none | `30s`, `1h30m` |
| Canonical form | none | defined, so equal values give equal bytes |
| Design rationale in the spec | three sentences, no FAQ | a [design principles](spec.md#design-principles) section |

**TOML gives up on data, on purpose, and says so.** From the TOML README, verbatim:

> "Because TOML is explicitly intended as a configuration file format, parsing it is easy, but it is not intended for serializing arbitrary data structures. TOML always has a hash table at the top level of the file, which can easily have data nested inside its keys, but it doesn't permit top-level arrays or floats, so it cannot directly serialize some data."

A long-time contributor drew the same line in [#762](https://github.com/toml-lang/toml/issues/762): "For general-purpose data definition, though, that's not something that TOML v1.0 will be addressing." SOML keeps JSON's tree of objects and arrays instead, so one format covers config and data. This is the largest structural difference between the two.

**One trap TOML has and SOML does not.** The TOML spec carries this, with a warning of its own:

> "Since bare keys can be composed of only ASCII integers, it is possible to write dotted keys that look like floats but are 2-part dotted keys. Don't do this unless you have a good reason to (you probably don't)."

```toml
3.14159 = "pi"      # maps to { "3": { "14159": "pi" } }
```

The same rule turns `example.com`, `socket.io`, and `tls.crt` into nested tables. TOML's answer is advice, because its grammar permits these keys. SOML has no dotted keys, so a `.` in a bare key is an error, and the message says to write `'3.14'` instead. A rule that a parser can check is checked. The [FAQ](faq.md#why-no-dotted-keys-as-in-ab-1) says why SOML gives up dotted keys to get this.

**Four temporal types, three of which are not instants.** TOML has offset date-time, which is the instant, plus local date-time, local date, and local time. In 2015 a maintainer recalled that "Datetimes were on the brink of being removed from TOML because their use cases weren't very compelling in a configuration format". Another participant in that thread stated the principle that SOML adopts: "Dates and times are not instants." SOML has one point-in-time type, it is always an instant, and the offset is mandatory.

**The rationale nobody wrote down.** TOML's stated objectives are three sentences, and it has no FAQ ([the issue proposing one](https://github.com/toml-lang/toml.io/issues/70) has been open since 2023). SOML states its principles, so that "why does SOML not do X" has an answer.

## vs YAML

YAML is the format people like until it hurts them, and both halves of that sentence are true. SOML takes the features that work and removes the two mechanisms that cause the harm.

**Be fair about the famous bugs first.** The Norway problem, sexagesimal numbers such as `22:22` becoming 1342, `0777` as octal, and `on:` as a boolean key are all YAML **1.1** problems. They were fixed in YAML 1.2, published in 2009. The reason they persist is adoption, not the specification. PyYAML implements YAML 1.1 and says so on PyPI, and the request to add 1.2 support has been open since 2017-12-27 with no resolution; the pull request implementing it is also still open. So the common experience of YAML is 1.1 through PyYAML, and blaming "YAML" for those four bugs is imprecise.

**But YAML 1.2 still has the core problem, and it is the reason SOML is strict.** Implicit typing survives in the 1.2 Core Schema, which the specification recommends as the default. Its resolution table maps `null`, `Null`, `NULL`, and `~` to null, an empty scalar to null, three case variants of `true` and `false` to booleans, `[-+]?[0-9]+`, `0o[0-7]+`, and `0x[0-9a-fA-F]+` to ints, and `[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?` and the `.inf` and `.nan` spellings to floats, with everything else a string.

That table is applied silently. `zip: 01234` is the integer 1234 under a conforming 1.2 Core Schema parser, and 668 under the 1.1 parsers most people actually run, because 1.1 read a leading zero as octal. Either way the leading zero is gone, nothing reports it, and two parsers disagree about the value. `version: 10.23` is a float, while `9.5.25` stays a string, so the failure appears the moment a version number grows a decimal point. As Ruud van Asseldonk put it: "imagine updating a config file that lists a single value of 9.6.24 and changing it to 10.23. Would you remember to add the quotes?"

Three further points make this a design problem rather than a documentation problem.

1. **The Core Schema is a recommendation, not a requirement.** The specification says a processor "should use" it "unless instructed otherwise", and its preview chapter says that untagged nodes "are given a type depending on the application". Nothing obliges a parser to follow the table.
2. **The same bytes resolve differently across the ecosystem.** `date: 2024-01-01` becomes a language date object in PyYAML, Ruby's Psych, js-yaml 4.x, and Go's yaml.v3, and stays a string in js-yaml 5.x, goccy/go-yaml, and eemeli's `yaml`. `!!timestamp` was dropped from YAML 1.2, so the newer parsers are the correct ones, and the disagreement is live.
3. **The specification admits a defect it chose not to fix.** Its own footnote on the JSON schema: "The regular expression for float does not exactly match the one in the JSON specification, where at least one digit is required after the dot... The YAML 1.2 specification intended to match JSON behavior, but this cannot be addressed in the 1.2.2 specification."

So the disagreement is not an implementation slip. SOML's answer is to remove the mechanism rather than to narrow the table, as [principle 1](spec.md#design-principles) says. A quoted string is never retyped. `'01234'` is a string. `01234` is an error, because leading zeros are not permitted. No parser will ever turn your version number into a float.

**Indentation is significant, and YAML had to ban tabs to survive it.** §6.1, verbatim:

> "To maintain portability, tab characters must not be used in indentation, since different systems treat tabs differently."

This is the strongest single argument against indentation-as-structure. The most widely used indentation-sensitive format forbids a character that every keyboard has, because the same bytes would otherwise mean different documents. SOML keeps indentation for readers and takes it away from the parser, so a tab is whitespace like any other and no document changes meaning because of invisible leading space.

**Comments are declared not to be content.** §6.6: comments "are a presentation detail and must not be used to convey content information". The consequence is that no conforming tool can promise to preserve them, which is why round-tripping YAML needs special modes. SOML states the same rule explicitly, so that nobody builds on a property the format does not offer.

**Two of YAML's features are a permanent security surface, and they fail in two different ways.**

**Aliases make parser cost unbounded, which is a denial-of-service class.** The specification makes anchor names "a serialization detail" that "must not be used to convey content information", and RFC 9512 adds that "YAML documents are rooted, connected, directed graphs and can contain reference cycles, so they can't be treated as simple trees."

- **CVE-2024-35221**: a gem publisher could denial-of-service rubygems.org through a YAML bomb in gem metadata, because RubyGems' `SafeYAML.load` wrapper turns aliases on. Ruby's own `safe_load` rejects aliases by default, so the lesson is that a loader named "safe" is only as safe as its options.
- **CVE-2019-11253** (7.5): a malicious YAML payload crashes the Kubernetes API server.
- **js-yaml published eight advisories in 2026, four of them rated high**, most of them complexity and denial-of-service bugs in the merge key, aliases, `!!omap`, and flow collections. The merge key and `!!omap` are features YAML 1.2 dropped. Aliases it kept, so the cost of aliases is permanent.

**Tags, and the loaders that resolve them, are a remote-code-execution class.** This one is partly the libraries' fault rather than the syntax's, and it is worth saying so, because it is the one criticism here that does not go away when YAML is used carefully.

- **PyYAML has four remote-code-execution CVEs, all CVSS 9.8**, including three against `FullLoader`, which PyYAML made the default in 5.1 and advertised as avoiding arbitrary code execution. Two of the four are incomplete fixes for earlier ones. Its own wiki warned of that loader as of 5.3.1: "there are still trivial exploits. Do not use this on untrusted data for now."
- **CVE-2022-32224** (9.8): `YAML.unsafe_load` on serialized columns in Rails lets an attacker who can already write to the database escalate to remote code execution. The advisory notes that "other coders (such as JSON) are not impacted".

The mitigation has never been to remove either feature. It has been to keep adding limits and changing defaults. SnakeYAML's alias limit for collections defaults to 50, its nesting depth limit defaults to 50, and its documentation says of recursive keys, "do not rely on this setting for untrusted input."

SnakeYAML's own README pushes back and the objection is fair: "When you use SnakeYAML to configure your application you are totally safe." That is true for trusted input. It is not true for untrusted input, such as gem metadata on a public registry.

SOML has neither aliases nor a tag system. The first class is inexpressible in it, and the second cannot occur, because nothing in the format names a type to instantiate.

**1.2 adoption is incomplete, so "just use 1.2" is not available.** The most-used Go library carries the heading "THIS PROJECT IS UNMAINTAINED", is archived with 422 open issues and pull requests, and describes itself as supporting "most of YAML 1.2, but preserves some behavior from 1.1": 1.1 booleans when decoding into a typed boolean, `0777` octals rather than `0o777`, and no base-60 floats. It is a deliberate mix, and it is neither version. Kubernetes consumes the fork of that same library that the YAML organization maintains, not a 1.2 alternative. PyYAML is 1.1. Rust's `serde_yaml` is archived, with the literal version string `0.9.34+deprecated` and no designated replacement. libyaml has had no stable release since 2020, though a release candidate appeared in 2026. In the YAML project's own test matrix, whose newest snapshot is from 2022, PyYAML passes 329 of 402 cases and libyaml 330.

**The strongest criticism is not any single bug.** It is van Asseldonk's: "any construct not explicitly forbidden will eventually make it into your codebase, and I am not aware of any good tool that can enforce a sane yaml subset." He also makes the point that no two syntax highlighters agree on which scalars are not strings: "Vim, my blog generator, GitHub, and Codeberg, all have a unique way to highlight the example document from this post. No two of them pick out the same subset of values as non-strings!"

**And Kubernetes reached the same conclusion in 2026.** Its own engineering blog says: "The problem isn't that YAML is a bad format. It's that YAML gives you a lot of choices... Some values that look like strings get coerced into other types without warning. The classic example is the 'Norway Bug'." Their answer is a strict subset, and its description is worth reading twice: "It does not introduce a new format or a new parser. It just narrows the scope of choices you make when writing YAML." One of the largest YAML ecosystems concluded that the fix is to restrict the language. SOML makes the same restrictions, as a format with its own grammar rather than as a subset, for the reasons given under "Why not just restrict YAML" below.

**The defence, for completeness.** The best counterargument is that these complaints target YAML 1.1 through PyYAML, and that the old tooling is broken, not the format. The first half is true, and the sections above respect it. The second half does not hold: a backwards-incompatible revision cannot become the default without breaking every existing user, and a specification the installed base does not implement has no practical force.

**What SOML takes from YAML:** comments, multi-line strings, and a top level with no braces and no commas. SOML separates items with line breaks, not with indentation. SOML's block strings use Swift's rule, one delimiter pair with automatic dedent, instead of YAML's six chomping combinations (`|`, `|-`, `|+`, `>`, `>-`, `>+`) plus an optional 1-through-9 indentation indicator. YAML's specification calls chomping "a presentation detail", but its Example 8.4 shows that a reader still has to know the indicator to know the resulting string. SOML has one rule and no indicators.

YAML's other real capability is multi-document streams, which JSON cannot express at all. SOML leaves that out of v1 on purpose, so that one file is always one document. It is listed as a non-goal rather than left as an oversight.

## vs the rest

**Eon is the closest existing format to SOML.** Eon describes itself as "a simple config format designed for human editing" and a replacement for TOML and YAML, and it makes many of the same moves: no braces at the top level, optional commas, unquoted identifier keys, `//` comments, four string styles taken from TOML, `0xdead_beef` with underscore separators, and signed `+inf` and `+nan`. It has had one release, 0.2.0 in 2025, and none since. So the space is not empty, and the honest framing is that SOML is a second attempt at Eon's idea with different tradeoffs, not the first attempt at a new idea.

**KDL solves a nearby problem by changing the data model.** Its spec is finalized at 2.0.0, and the project states that no further changes are expected. It has real adoption in CLI and desktop tools. But a KDL document is a list of named nodes rather than a map, so it is not a substitute for JSON-shaped data, and it does not guarantee property order. It occupies a different slot.

**Pkl answers a different question.** It is a configuration *language* that compiles to JSON, YAML, and plists, and it places itself against Jsonnet, HCL, and Dhall. More than two and a half years after it was open-sourced, in February 2024, it is still before 1.0, at 0.32.1. It answers "how do I compute configuration", not "what should a configuration file look like".

**HOCON is the cautionary tale for dotted keys, and part of why SOML has none.** HOCON reached dotted-path nesting sugar in 2011, more than a year before TOML existed, and it is the standard configuration format of Akka, Pekko, and Play. It is also what happens when merging is permitted:

> "duplicate keys that appear later override those that appear earlier, unless both values are objects... If both values are objects, then the objects are merged."

and a non-object value "simply wins and loses all information about what it overrode". Merging is pairwise and order-sensitive, and it switches on whether both sides happen to be objects, so two files that look alike can produce different results. HOCON also concedes that a key containing a literal dot cannot be represented in a properties file at all.

Its own specification advises against a `.` in a key: "It is not recommended to name HOCON keys with a `.` in them, since it would be confusing at best in any case." Its issue [#493](https://github.com/lightbend/config/issues/493), "No way to declare key/values (containing dots) sharing a part of the path", is still open.

SOML keeps HOCON's rule that a quoted key is literal, so `'a.b': 1` is one key, and it merges nothing: two members with the same key are an error. Two documents that look alike therefore never give different results because of the order of their members.

| Format | What it is | Why it does not cover this ground |
|---|---|---|
| **NUON** | Nushell's native format, and a JSON superset | Nushell only, and it cannot express everything a Nushell value can |
| **HuJSON / JWCC** | Tailscale's JSON with comments and trailing commas | It keeps JSON's braces, quoted keys, required commas, and every semantic defect |
| **StrictYAML** | A schema-validated YAML subset | Dormant since 2023, and still YAML underneath |
| **HJSON** | 2014 "human JSON" | Maintained in Go, but its npm package has had no release since 2020 and has about 500,000 weekly downloads against about 290 million for JSON5, which shows that demand for a friendlier JSON exists and that HJSON is not its shape |
| **RON** | Rusty Object Notation | A data model that follows Rust and serde, with optional struct names. Rust programs use it for configuration and Bevy scenes, but tools outside Rust use it little |
| **CUE, Dhall, Jsonnet, Nickel, KCL** | Configuration *languages* | They compute configuration rather than describe it, and they compete with each other, not with JSON |
| **HCL, Starlark, Bicep** | Configuration languages of particular tools | Each is tied to one vendor's tools |

**Why not just restrict YAML, the way Kubernetes did?** This is the strongest objection in the document, and it deserves a direct answer, because Kubernetes did exactly that. KEP-5295 introduces KYAML, a strict YAML subset, now stable in Kubernetes 1.37, and its stated motivation is the section above: significant whitespace, silent coercion, and a broad specification with a reasonable grammar inside it.

Their non-goal, stated in the same document, is to "introduce alternative configuration languages that are not compatible with existing tooling". That constraint is why they chose a subset rather than a format, and for Kubernetes it is the right choice, because every existing YAML parser keeps working.

The constraint does not apply to SOML, and a subset inherits three costs a new format does not. It inherits YAML's grammar, and therefore its parser complexity and its ambiguity. It inherits YAML's security surface, and the merge key is the clearest case: undefined in the current standard, widely supported anyway, and still producing advisories, because parsers kept the feature that 1.2 dropped. And it can only remove, never add: a subset can forbid duplicate keys, but it cannot add a duration, separate an int from a float in every parser, or define a canonical form. Choosing a subset is right when compatibility is the hard requirement. It is wrong when correctness is.

**And the field is crowded enough that the real barrier is distribution.** Kubernetes' design proposal, from 2017, named the alternatives in one sentence: "It would also be nice to support a less error-prone data syntax than YAML, such as Relaxed JSON, HJson, HCL, StrictYAML, or YAML2. However, one major disadvantage would be the lack of library support in multiple languages."

That is an honest statement of the situation, and it is about distribution rather than design. For SOML it means one thing: the design has to be good enough that writing a parser in a second language is worth someone else's time.

## When another format is the better choice

SOML is for files that people write, read, and change by hand, where a value must mean the same thing in every parser. Outside that, another format is often the better choice, and the reasons are worth stating plainly.

- **Data between programs.** JSON has a fast and well-tested parser in every language, and the things SOML adds matter most to a person reading the file. RFC 8785 gives JSON a canonical form when one is needed.
- **A tool that already reads another format.** Kubernetes reads YAML, Cargo and `pyproject.toml` read TOML, and a format is only useful where its parsers are. SOML is a draft, and its libraries cover a few languages so far.
- **Configuration that is computed.** CUE, Dhall, Jsonnet, Nickel, and Pkl can import files and compute values, and most of them add types or constraints. SOML describes values and does not compute them.
- **Several documents in one stream, or shared fragments.** YAML has multi-document streams and anchors. SOML has neither on purpose, so a file is one document and a value is a tree.
- **Values that SOML refuses.** A local date or time without an offset, an int beyond 64 bits, NaN, a signed zero, and binary data have no type in SOML. TOML has local dates and times, and the others are written as strings.
- **A frozen standard.** JSON, YAML 1.2, and TOML 1.1 are stable. SOML is a draft.

# FAQ

Short answers to common questions. The [spec](spec.md) has the full reasons, and [comparison.md](comparison.md) has the evidence.

- [General](#general)
- [Syntax](#syntax)
- [Types](#types)
- [Strictness](#strictness)
- [Tools](#tools)

## General

### Why another format?

Because JSON is noisy to write by hand. Every key needs quotes, every member needs a comma, the document needs outer braces, and there are no comments. SOML keeps most of JSON's data model and removes the noise: keys are bare, line breaks replace commas, the top level needs no braces, and comments are allowed. It also adds literal strings, block strings, date-times, durations, and separate int and float types.

The formats that are easier to write have other problems. YAML guesses types from content, so `version: 10.23` becomes a float, and `zip: 01234` becomes the number 1234, or 668 in YAML 1.1 parsers such as PyYAML. JSON5 and JSONC add comments, but JSONC keeps the quoted keys and commas, and JSON5 keeps the commas and needs quotes for a key with a dash. TOML is good, but it cannot have a top-level array or null, and it has three ways to nest: table headers, dotted keys, and inline tables.

SOML also decides what JSON leaves to the implementation: duplicate keys, lone surrogates, and integers past 2^53. JSON implementations disagree on these, and JSON5 and JSONC do not decide them either.

### What is SOML for?

Files that people write and read: config files first, and also data files, test fixtures, and manifests. Unlike TOML, SOML keeps all of JSON's data model, including null and a top-level array, so one format holds both config and data. A program can also write SOML. A serializer keeps the order of the keys it is given, and its canonical form gives one value the same bytes every time, for hashing and comparing. For data that no person reads, such as API responses, SOML's authoring features matter little, and JSON has far more tools.

### Why not write config in a programming language?

Because a config file that runs code can do anything, and every tool that reads it needs that language's runtime. A data file can be read by any language, formatted, diffed, and changed by a program. SOML describes values. Configuration languages such as CUE, Pkl, and Dhall calculate them, and they solve a different problem.

### Why not a strict subset of YAML, as Kubernetes did with KYAML?

A subset is the right choice when existing YAML tools must keep working, and that is why Kubernetes chose it. But a subset keeps YAML's large grammar and its security problems, and it cannot fix what JSON leaves undecided, because a subset can only remove things. [comparison.md](comparison.md#vs-the-rest) has the full answer.

### Is JSON valid SOML?

Hand-written JSON usually is, and `1` becomes an int and `1.5` becomes a float. The main parts of JSON that are errors in SOML are whitespace before a `:`, the `\u0041`, `\/`, `\b`, `\f`, and `\r` escapes, `1E5`, `1e+5`, and `1e-05`, `-0`, integers outside int64, duplicate keys, a top-level scalar, a comma at the start of a line, a BOM, floats such as `1e400` that are too large or too small for a 64-bit float, nesting deeper than 100 levels, and a carriage return anywhere, including CRLF line endings. JSON that programs write often uses these: JavaScript writes `1e+21`, Python writes `1e-07` and `\u00e9`, Go writes `-0` for a negative zero, and Jackson's pretty printer writes `"key" : value`. Most of the error messages tell you what to write instead.

### Is SOML stable?

Not yet. SOML is a draft. The plan is to freeze version 1 and then make no breaking changes, which is why a file has no version number. The spec has a complete grammar, and its [conformance suite](conformance) has nearly 1000 test cases that every implementation can use.

### What is the file extension and media type?

The extension is `.soml`, and the media type is `application/soml`. On Apple platforms, the Uniform Type Identifier is `com.sindresorhus.soml`. The [spec](spec.md#file-type) has the details.

## Syntax

### Why must strings be quoted?

Because an unquoted string makes the parser guess the type from the content, and that is YAML's worst problem. The best-known case is the Norway problem: in YAML 1.1 parsers such as PyYAML, `country: no` is the boolean `false`, so the country code of Norway disappears. In SOML, `country: no` is an error, and `country: 'no'` is a string. The problem also affects numbers. In YAML, `version: 10.23` is a float, but `version: 9.5.25` is a string, so the type changes when the version number changes. In SOML, the syntax alone gives the type: `'10.23'` is a string and `10.23` is a float, always.

Keys are the exception. A key is always a string and is never converted, so `404:` and `content-type:` need no quotes.

### Why two kinds of quotes?

`'...'` is literal, and `"..."` has escapes. This matters only when the text has a backslash, and that is where config files break. `'C:\Users\sindre'` and `'^\d{4}$'` are correct as written. In JSON, they must be `"C:\\Users\\sindre"` and `"^\\d{4}$"`.

Use `'` by default. Use `"` when you need an escape, or when the text contains a `'`. Shell and TOML use the same rule.

### Why `#` for comments?

Because `#` is one character, not two like `//`, so it is less noise on every comment line. It is also the comment character in almost all config files that people already edit: YAML, TOML, `.env`, `.gitignore`, Dockerfiles, shell scripts, and Python, so everyone reads it as a comment.

`/* */` does the other job: a comment that spans many lines, or that is in the middle of a line. SOML does not have `//`, because it does the same job as `#`, and a second spelling of one thing must earn its place.

### Why is indentation not significant?

Because indentation does not survive everything that handles text: copy and paste, chat apps, Markdown, templates, and editors that change tabs to spaces. YAML forbids tabs in indentation for a similar reason: "different systems treat tabs differently". In SOML, braces give the structure and indentation is only for the reader, so a file has the same meaning however it is indented. Block strings are the one exception, because their indentation is part of the text.

### Do I need commas?

Only between items on the same line, as in `[1, 2, 3]`. Inside `{}` and `[]`, a line break also separates items, so a list with one item per line needs no commas, and adding an item changes one line in a diff. A line break is safe as a separator, because SOML has no operators and no value that a following line can extend. JSON's commas still parse, and so does a trailing comma, as long as each comma is on the line of the item before it.

Most config files are one object, so a top-level object can leave out its braces. There, entries are always one per line, so commas are not allowed.

### Why can a comma not start a line?

Because there it does nothing. A line break already separates the items, so a comma at the start of the next line is a second separator. The comma-first style exists to keep a diff to one line where a trailing comma is not allowed. SOML allows a trailing comma, and items on separate lines need no comma at all, so the style has nothing left to fix. One place for a comma also means one layout for every formatter and editor to handle.

### Why do nested objects need braces?

Because without braces, something else must show where an object ends: significant indentation, a marker such as YAML's `- `, or an end keyword. Indentation would break the rule that indentation is not significant, and the other two add a second syntax for objects. So a list of records is `[{name: 'a'}, {name: 'b'}]`. The top level is the exception, because a file has only one top level, so there is no end to show.

### Why no dotted keys, as in `a.b: 1`?

Because in SOML they would cost more than they save.

- **They save little.** TOML needs them because it nests with table headers, and a dotted key sets one nested value without a new header. SOML has no headers. It nests with braces, and braces fit on one line: `server: {port: 8080}` is three characters longer than `server.port: 8080`. With two members or more, braces are shorter for any prefix longer than three characters, because each dotted key writes the prefix again.
- **They silently change real keys.** Host names, package names, and file names are common keys: `socket.io: '^4'`, `github.com: …`, `tls.crt: …`, and `Microsoft.AspNetCore: 'Warning'` in .NET logging. With dotted keys, each one becomes nested objects without an error, and the program then ignores the setting or fails far from the cause. That is YAML's `country: no` problem, moved from values to keys.
- **Tools that split keys on `.` keep backing out.** Spring Boot needs `[a.b]` brackets for such keys, Helm needs `\.`, and Viper and Spring each reverted a fix because it broke users. [OmegaConf](https://github.com/hydra-ecosystem/omegaconf/issues/332) dropped the same plan because it caused "too many issues", and [TOON](https://github.com/toon-format/spec/blob/main/.out-of-scope/key-folding.md) dropped its dotted-key folding eight months after it added it.

So a `.` in a bare key is an error, and the message says what to write instead: `'example.com': 1` for a key with a dot, or `a: {b: 1}` for nesting. If dotted keys ever earn their place, adding them will break no file. Removing them later would break many.

### Why must a key with a dot be quoted?

Because a bare `.` would surprise someone either way. To a TOML, HOCON, Nix, or Spring user, `logging.level: 'info'` sets `level` inside `logging`. To a JSON user, `example.com: 1` is one key. Whichever reading SOML picked, a file written by the other group would load with a different shape and no error. So neither reading exists: `'example.com': 1` is one key, and `logging: {level: 'info'}` is nesting. It costs two characters, and only for keys that contain a dot.

### Why must a document be an object or an array?

So that every reader gets an object or an array, and never has to check whether the file held a number. A document can also grow: a second setting is one more line, and a file that holds only `5` has no key to say what the value is.

An empty file, or a file with only comments, is also an error, because a document must have a value. Write `{}` for an empty config.

### Why do block strings use the indentation of the closing delimiter?

Because then you control the indentation of the text. The closing `'''` marks the left edge, and each line keeps what is to the right of it. With the other common rule, which removes the smallest indentation of the text lines, as Python's `textwrap.dedent` and Kotlin's `trimIndent` do, you cannot indent every line of the text. Swift and C# use the closing delimiter in the same way. The value also starts and ends with text, not with a line break.

## Types

### Why are int and float different types?

Because `replicas: 3` and `ratio: 0.75` are different kinds of number, and one number type causes real bugs. In JSON, `9007199254740993` becomes `9007199254740992` in JavaScript, and nothing reports it. A validator also cannot tell if `workers: 4.0` was meant as a count.

In SOML, `3` is an int64 and `3.0` is a float. They stay different after a round trip, and they map directly to `Int64` and `Double` in Swift, `i64` and `f64` in Rust, and `int64` and `float64` in Go. TOML made the same choice.

### Why only int64? What about decimals and big numbers?

Because int64 and 64-bit floats are native in almost every language, so every reader can hold every value exactly. A larger number is an error, not a silent float. For money, use an int of the smallest unit, such as cents, or a string. For a number past int64, such as a 128-bit ID, use a string.

### Why is `0644` an error?

Because readers do not agree on what it means. C and YAML 1.1 read it as the octal number 420, and JSON does not allow it. Write `0o644` for octal, or `644` for decimal.

### Why must hex digits be uppercase?

Because hex that stands alone is read as bytes, and bytes are often written in uppercase, as in `#FF8800` and `FF:FF:FF`. So `0xFF` is correct and `0xff` is an error. One fixed case means that tools never have to normalize it. The prefix is lowercase (`0x`, `0o`, `0b`), and so are the digits in a `\u{…}` escape, because that escape is inside text.

### Why a duration type?

Because `timeout: 30` makes every reader guess the unit. That is why config files have keys such as `timeout-ms` and `interval-seconds`. `30s`, `1h30m`, and `250ms` contain their unit, and the value is an exact count of nanoseconds. The units come from Go, with stricter rules: the units go from largest to smallest, and each is used at most once.

There is no `d` unit, because a day can be 23 or 25 hours when daylight saving time changes. Write `24h`. SOML does not use ISO 8601's `PT1H30M`, because it is hard to read, and `P1M` is one month while `PT1M` is one minute.

### Why is there only one date and time type?

Because only a date and time with an offset is one exact moment for every reader. `2026-09-19T14:00:00Z` is an `instant`, and the offset is required. A date with no time, or a time with no offset, is a different moment in each time zone, so SOML does not make it a type. Write it as a string. TOML has four date and time types, and SOML has one.

### Why does SOML have null? TOML does not.

Because "set to nothing" and "not set" are different. `owner: null` says that there is no owner. A missing `owner` says that the file does not set it, so a default can apply. Without null, every program must invent its own way to say the first one.

### Why no NaN?

Because NaN means that a calculation failed, and a config file does no calculations. It is also not equal to itself, which breaks equality and hashing. If a value is unknown, use `null`. `infinity` and `-infinity` are in the format, because `limit: infinity` has a clear meaning.

### Why no binary type?

Because it would need a syntax of its own, and config files rarely hold bytes. Use a string, with an encoding such as base64.

### Why `\u{e9}` and not JSON's `\u00e9`?

Because the braced form reaches every Unicode character except CR with one escape. JSON's form has exactly four digits, so an emoji needs two escapes, `\ud83d\ude00`, and a pair written wrong gives a broken string. In SOML, it is `\u{1f600}`. Rust, Swift, and JavaScript have a similar braced form, but SOML allows only lowercase digits and no leading zero.

## Strictness

### Why so strict?

Because a parser that guesses hides bugs, and two parsers that guess differently give two different values for one file. SOML makes each ambiguous case an error with a clear message, so a file has one meaning everywhere. Some rules also give each value one spelling, such as uppercase hex and a lowercase `e`, so that tools have nothing to disagree about. None of this takes away convenience: comments, optional commas, bare keys, and block strings are all allowed.

### Why are duplicate keys an error?

Because when a file has a duplicate key, different parsers keep different values, and attackers have used this. In CVE-2017-12635, two parsers in CouchDB read different `roles` keys from one document, and any user could make themselves an admin. A duplicate key is almost always a mistake, so SOML reports it.

### Does SOML keep the order of keys?

The order is not part of the value, as in JSON. So `{a: 1, b: 2}` and `{b: 2, a: 1}` are equal. A formatter keeps the order you wrote, and a serializer keeps the order it is given. Only canonical form sorts the keys, because it must give equal values equal bytes. If the order is data, use an array.

### Why are carriage returns (CRLF) an error?

Because a CR adds no information to the LF after it. If SOML accepted CR, every parser would have to remove it, and parsers would accept files that no SOML writer makes, which is how a format gets dialects. Add this line to `.gitattributes`:

```
* text=auto eol=lf
```

For files that are already in the repository, run `git add --renormalize .` once. All current editors support LF line endings, including Notepad since 2018.

There is no `\r` escape either. A CR is not part of any SOML value, so the rule is the same in a file and in a string. If a protocol needs `\r\n`, the program that uses the value must add the CR.

## Tools

### Is there a schema?

No. A schema belongs in the tool that reads the file, where it can be versioned and tested. SOML's types make validation easier: `3` and `3.0` are different, and the parser already checks every instant and duration.

### Why not make every value a string, and let a schema give the type?

StrictYAML and NestedText do this. It is a valid design, but then the file has no meaning without the program that reads it. A formatter, a diff tool, a converter, and a second program in another language all see only strings, and each must apply the schema again. In SOML, the syntax gives the type, so every reader gets the same value from the file alone.

### Can a program change a value and keep my comments?

Comments are not part of the value, so if a program parses a file and writes the value back, the comments are lost. To keep them, a tool must change the text of the file, not write a new one. The spec defines a formatter that keeps your comments, order, and spelling, and its Editing section says how a tool changes one value and keeps everything else. Whether a library does this depends on the library.

### Why is there a canonical form?

So that one value always gives the same bytes. Two programs that write the same value in canonical form give identical files, so you can hash, sign, cache, and compare them. Canonical form is for programs that compare bytes, so it sorts the keys. When a program writes a file for people, a serializer keeps the order it is given and follows every other canonical rule. A separate formatter keeps your comments, your order, and your spelling.

### Is it safe to parse untrusted SOML?

The format has nothing that runs code or makes a document larger when it is read: no tags, no anchors, no includes, and no type names that a loader could create. Every number, instant, and duration has a fixed range, and nesting is limited to exactly 100 levels, so every parser accepts the same documents. A program should still limit the size of the input.

### Why no anchors, includes, or variables?

Because a config file must give values, not calculate them. Anchors make a document a graph instead of a tree, and YAML's anchors make denial-of-service attacks such as YAML bombs possible. Includes and variables belong in the tool that reads the file, where you can test them.

### Why only one document per file?

So that a file is one thing that you can name, and a stream of documents is a stream of files. YAML's `---` makes every reader handle more than one document, even when a file never has more than one.

# SOML specification v0.1

*Draft.*

> [!NOTE]
> SOML is short for Sindre's Objectively Marvelous Language.

> [!NOTE]
> The introduction and examples are in [readme.md](readme.md). The comparisons with JSON, JSON5, JSONC, TOML, and YAML are in [comparison.md](comparison.md). Short answers to common questions are in [faq.md](faq.md).

## Design principles

These are what keep a larger feature set from becoming a harder language.

1. **A value's type comes from its syntax, never from its content.** `'123'` is a string and `123` is an int. Nothing is ever retyped by inspecting it. This single rule removes the entire class of bug that YAML is famous for.
2. **Every alternate spelling must earn its place.** Several spellings for one value are allowed only when they materially help someone write or read the file, and canonical serialization always chooses one of them. `16`, `0x10`, and `0b10000` are one integer; `'a'` and `"a"` are one string; `a: 1` and `{a: 1}` are one object. A spelling that does not earn its place is not in the format.
3. **Nothing is significant but the tokens and the line breaks between them.** A line break between two entries or items, outside a comment, separates them, and nothing else about whitespace changes the structure. Indentation never does, so leading whitespace is never load-bearing and a file survives copy-paste, markdown fences, and every editor. Block strings are the one deliberate exception, and they are the only place where leading whitespace is content.
4. **Every ambiguity is an error, not a guess.** Duplicate keys, lone surrogates, a BOM, a `.` in a bare key. A parser that guesses is a parser that hides a bug.
5. **Reject the invisible.** Only space, tab, and LF count as whitespace. No CR, no other C0 control or DEL, no other Unicode whitespace, no BOM. Characters you cannot see should not be able to change your config. Strings and comments are the exceptions. A quoted string or key may hold an invisible character such as U+200B or U+00A0, because a string holds text and text can contain one. A comment may hold one too, because a comment is not content. CR and the other control characters stay refused in both.
6. **The grammar must fit in an afternoon.** No backreferences except the length of a block string's delimiter, no indentation stack, and no content sniffing. It is one pass over the token stream with no lookahead, because a document's form is decided by its first character after whitespace and comments. Block strings and `/* */` comments are the only constructs that must be buffered to their terminator.

## Data model

A value is one of: string, int, float, bool, null, instant, duration, array, or object. That is JSON's model with three changes and two limits. Numbers split into int and float, which are different types rather than one `number`. `instant` and `duration` are added, because an instant is not a string and a duration is not a number. And `infinity` becomes representable, which JSON forbids. The limits are that an int is an int64 and a string cannot hold U+000D.

An array is an ordered sequence of values. An object is a collection of key and value pairs whose **order is not significant**, so these two documents hold the same value:

```
{a: 1, b: 2}
```

```
{b: 2, a: 1}
```

This follows JSON, whose objects are "an unordered collection of zero or more name/value pairs", and whose §4 adds that "Implementations whose behavior does not depend on member ordering will be interoperable". Making order part of the value would be a larger departure from JSON than anything else in this specification, and it would force every implementation to carry an ordered map just to answer whether two documents are equal.

It matters in exactly two places. A **formatter** keeps the order it was given, because a human chose that order and wants their diff to stay small, and a tool that edits one value keeps it the same way. A **serializer emitting canonical form** sorts, so that two documents with the same members produce the same bytes and therefore the same hash. A serializer that writes a file for people may keep the order it was given instead, as the Canonical form section says. When order genuinely is data, write an array of single-member objects, which states the ordering in the data rather than leaving it in the layout.

## Encoding and newlines

A file is UTF-8 with no BOM. A BOM is an error. LF ends a line.

A byte sequence that is not well-formed UTF-8 is an error. That includes an overlong form, an encoded surrogate, a sequence above U+10FFFF, and a sequence that the end of the file cuts short. A reader must not replace one with U+FFFD, because then two readers could give two values for one file.

A BOM is U+FEFF as the first character of a file. Elsewhere, U+FEFF has no special meaning. Between tokens it is an error, as any character that is not whitespace is, and inside a string or a comment it is part of that string or comment, like U+200B and the other invisible characters that this section does not refuse. Treating it as a BOM anywhere but the start would give one character two meanings, and refusing it only inside strings would single it out from the many invisible characters a string may hold.

**A carriage return is not part of SOML.** It may not appear anywhere: not as a byte in a file, not as the first half of a CRLF pair, and not inside a value. U+000D is a character this format does not represent.

The case against CR is not that it is hard to handle. It is easy to handle, and that is the problem. Every reader would have to strip CRs before it could read the document, so accepting them adds no capability. It adds a preprocessing step that every implementation has to write, every implementation has to test, and every conformance suite has to cover. And a character that is always discarded carries no information: there is nothing in a CRLF that is not already in the LF.

Ignoring CR silently is worse. It gives the format two dialects and lets a reader accept documents it would never emit, which is the liberal-input licence that let JSON's defects survive, and the reason two conforming readers can disagree about one file's bytes while both claim to be correct. Normalising CR instead changes the user's bytes without saying so, and then "is this file unchanged" has two answers instead of one. Refusing it costs one error message and one fix, paid once per repository:

```
* text=auto eol=lf
```

What that buys is that a document's bytes and its meaning are the same thing, so a formatted file is byte-identical to its formatted form and "has this file changed" is answered by the bytes rather than by a normalisation step first.

**CR is refused inside a value as well, and that is what makes this one rule rather than three.** Allowing it as an escape while forbidding it as a byte would work, but then the format has to explain the difference between a CR in a file and a CR in a string every time somebody asks, and it has to keep two code paths that must not disagree. Nothing needs explaining if U+000D does not exist here at all, and nothing is lost, because a CR inside a value is far more often the residue of a tool than something an author typed. A format whose premise is that a document contains what its author can see should not be how one arrives.

This is the same decision as the BOM, the non-ASCII whitespace, and the lone surrogate: characters that change nothing a reader can see but that an implementation would otherwise have to carry. CR is the most common such character in existence, and refusing the common case matters more than refusing the rare ones.

**The other control characters are refused as raw characters too.** U+0000 to U+001F, except tab and LF, and U+007F may not appear anywhere in a document: not in a string, not in a comment, and not between tokens. Unlike CR, they remain representable in a value, written as a `\u{…}` escape inside `"..."`, which is also how canonical form writes them. So `"\u{0}"` is a string holding NUL, and the same character typed raw between two quotes is an error. A raw NUL or backspace is invisible in every editor, and a document whose meaning depends on one is the case principle 5 exists to refuse.

The rules of this section apply to every byte, wherever it is: the file is well-formed UTF-8, it does not start with the bytes `EF BB BF`, and it holds no byte 0x00 to 0x08, 0x0B to 0x1F, or 0x7F. So a reader can check them in one pass over the bytes before it parses, and then a string or a comment needs no check of its characters.

## File type

- **File extension:** `.soml`
- **Media type:** `application/soml`
- **Uniform Type Identifier:** `com.sindresorhus.soml`, conforming to `public.text`

The media type takes no parameters, because a SOML file is always UTF-8. It has no `+json` suffix, because a SOML document is not JSON. It is not registered with IANA yet. TOML took the same path: its 0.5.0 specification named `application/toml` in 2018, and IANA registered it in 2024.

The Uniform Type Identifier is for Apple platforms. An app that opens SOML files declares it as an imported type in its `Info.plist`, because only a declared type is linked to the `.soml` extension and conforms to `public.text`.

## Whitespace

Outside a string or a comment, only space, tab, and LF are whitespace. A CR, and any other character in the Unicode whitespace categories including U+00A0 and U+2028, is an error there. A comment may hold any Unicode scalar value except the control characters refused above, because a comment is not content. Only LF ends a `#` comment, so a U+2028 inside one is part of the comment. Inside a string, any Unicode scalar value may be written as itself except LF in a single-line string and the control characters refused above, which are written as escapes, apart from CR, which is not representable at all.

Only a string can contain a character outside ASCII, so outside a string or a comment, every byte above 0x7F is an error. A reader needs no Unicode table to find one.

Indentation never changes the structure of a document, and a reader must not reject one because its indentation is spaces where another used tabs, or because a file mixes the two. The single place where leading whitespace carries meaning is the dedenting rule for block strings, which is stated under Strings. Indentation style is a formatter's concern, not the parser's, so the parser determines meaning and the formatter determines presentation.

## Comments

`#` runs to the end of the line. `/* ... */` spans lines and ends at the first `*/` that begins after its `/*`. The text between them is its body, and the body may not contain `/*`, so a nested opening is an error rather than a silent stop at the first `*/`. So `/* x /*/` is a comment whose body is ` x /`, and `/*/* */` is an error. Both may appear wherever whitespace may, as the Grammar section states: before and after the document's value, between entries and items, after a value on its line, after a `:`, after an opening bracket, and inside an empty `[]` or `{}`. Neither may appear inside a key, between a key and its `:`, or inside a number, an instant, or a duration.

Forbidding `/*` inside a block comment is a real restriction, and it has a real cost: you cannot write those two characters inside one at all, so a comment documenting a glob or a regular expression uses `#` or splits itself. The trade is made because an accidentally nested comment is far more common than an intentional one, and an error that names the problem beats a document that ends somewhere the author did not intend.

The two forms do two jobs, which is why both are here. `#` annotates the line it is on. `/* */` annotates a region, so a paragraph explaining a section does not need a `#` at the start of every line of it.

A comment is not content. A conforming reader may discard every comment, and no meaning in a document depends on them. This is stated as a rule rather than left implicit, so that nobody builds on a promise the format does not make.

## Document

A document is a collection: an object or an array. A top-level object may omit its braces, and that is the only omission. These three are documents:

```
key: 'value'
```

```
{a: 1, b: 2}
```

```
[1, 2, 3]
```

Why omit the braces at the top level when every other object requires them? Because of depth. Nearly every configuration file is one object whose members are the things a reader came to change, and braces with a mandatory indent would push every one of those lines a level further from the left margin while disambiguating nothing, because at the top level there is nothing to disambiguate.

Leaving them out is not free, and the price is worth stating. The top level becomes the one collection that ends at the end of the file rather than at a delimiter, so it needs its own separator rule, which permits line breaks only, and a clause in the formatter that preserves the missing braces. Requiring the braces would delete that in exchange for two characters and one indent level in every file. The trade is made in favour of the file, because a file is read on every occasion and the machinery is written once.

The form is decided by the first character, ignoring comments and whitespace. `{` or `[` begins a braced collection, and anything else begins a brace-less object, which then runs to the end of the file. So the grammar needs no lookahead at all.

**A bare scalar is not a document.** `5`, `true`, and `2026-09-19T14:00:00Z` are errors on their own, and each is written as a member or an array item instead. JSON began with the same rule: RFC 4627 says "A JSON text is a serialized object or array." RFC 7159 relaxed it, and RFC 8259 keeps the relaxed rule while noting that "Implementations that generate only objects or arrays where a JSON text is called for will be interoperable". TOML always has a table at the top. The rule is kept for three reasons.

- **Every reader gets one root type.** `parse` always returns an object or an array, so a typed API can say so, a decoder always starts from a container, and no caller has to check whether the file held a number. With scalars allowed, the root type widens to all nine value types and every caller has to handle all of them. A whole document of `null` or `false` would also look like "nothing was loaded" in many languages.
- **A document can grow.** An object takes a second setting by adding a line. A scalar document cannot take a second value without changing its root type, which breaks every reader of the file. A scalar also has no key, so nothing in the file says what the value is.
- **The grammar stays small.** If `404` could be a whole document, `404` and `404: 'x'` would begin with the same token, so the form of a document could no longer be decided by its first character, and the instant case below would be a real ambiguity rather than an error. Without scalar documents, no position exists where a key token and a value token compete, which is what makes the permissive key character set safe. The serializer and the formatter also only ever see a collection at the root.

It also removes a specific trap. A bare instant contains colons, so if a bare scalar could be a document, `2026-09-19T14:00:00Z` would begin with something readable as a key, `2026-09-19T14`, followed by its `:`. The reader would have to choose, and one reading would be wrong. Requiring a document to be a collection removes the choice. An implementation should still report this case well: a reader will have committed to the object reading before discovering that `00:00Z` is not a value, so it is worth an extra check to say that a bare scalar is not a document rather than reporting the failure inside the entry.

A brace-less object separates its entries with line breaks. Commas are not permitted at this level:

```
name: 'soml'
version: '1.0.0'
```

Inside `{...}` and `[...]`, a line break separates items in the same way, and a comma does too, so a braced collection can also be written on one line (see Arrays and objects). Two entries on a single line at the top level are an error, and the way to write a one-line object is to use braces. Commas are not permitted at the top level because a brace-less object is always written one entry per line, so a comma there could only be a second spelling of the line break.

After the top-level value, only whitespace and comments may follow. Anything else is an error. An empty document, and a document containing only comments, are errors, because a document must have a value.

## Keys

A bare key is one or more ASCII letters, digits, underscores, or dashes. There is no rule about the first character, so all of these are bare: `content-type`, `x-forwarded-for`, `_private`, `404`, `-foo`, `2024-01-01`, and `7zip-bin`. Only a key containing a space, a `.`, or any other character outside that set needs quotes.

**A key is always a string and is never coerced.** `404: 'not found'` has the string key `404`, not the integer key 404, and `2024-01-01: 'new year'` has a string, not a date. This is the property that makes the permissive character set safe, and it is the property YAML lacks. Under YAML's core schema, a plain key matching `[-+]? [0-9]+` resolves to an integer, so `404:` produces an integer key, and a common parser turns `007:` into `7`, `2024-01-01:` into a date object, and `yes:` into the boolean true. Key coercion, not the character set of keys, is what makes YAML keys a source of silent mismatch.

The character set is permissive because position decides meaning, not spelling. A key is the token before a `:`, and a value never occupies that position, so a key never needs to avoid looking like a number, a negative number, or an infinity. That is principle 1 applied to keys rather than values.

Two alternatives exist, and this specification rejects both.

**A first-character restriction.** XML names, POSIX environment variable names, and the shell all have one. HOCON has one for an unquoted string value and states the reason plainly: such a string "may not begin with the digits 0-9 or with a hyphen (…) because those are valid characters to begin a JSON number". That reason is about values, and a key is never read as a value, so it does not apply to keys, and HOCON's own keys may begin with a digit, because a HOCON key is always converted to a string. Every format that treats keys as opaque strings permits a digit first: JSON, where a name is always a string, TOML, whose spec prints `1234 = "value"` as a valid example, Java `.properties`, which has no first-character rule at all, the freedesktop INI dialect, whose rule is a character set rather than a first-character restriction, and Kubernetes ConfigMap keys. Even where the restrictive rule exists it has been relaxed: RFC 1123 changed host names to permit a leading digit and required implementations to support the looser syntax.

**Keeping the restriction for tidiness.** Real use does not support it. OpenAPI requires HTTP status codes as response keys, and its specification has to mandate quoting them precisely because YAML would otherwise turn `200` into an integer key. Kubernetes' documentation shows a ConfigMap that holds the keys `1badkey` and `2alsobad`, which are valid ConfigMap keys and are skipped only when they are used as environment variable names. npm package names may begin with a digit, so digit-first keys already occur in dependency maps. Ports, status codes, and numeric identifiers are natural map keys, and needing quotes for them is a cost paid on every read for no benefit.

**What SOML never does to a key.** It does not fold case, map a dash to an underscore, merge two keys, or sort them to decide identity. That matters more than it reads. RFC 9110 §17.10 describes a potential request smuggling vulnerability caused by exactly such a mapping: a gateway that converts `-` to `_` gives `Transfer_Encoding` and `Transfer-Encoding` the same name, and a naive interface then reads one for the other. A format cannot stop a consumer from flattening its keys, but it can decline to do it and make the keys it produces exact.

A quoted key is a `'...'` or `"..."` string, and it may contain anything a string may contain. It is single-line in the source, and a block string cannot be a key. Its value may still hold a LF written as `\n`, because a key is a string and has no rules of its own. It is the escape hatch for every key the bare rule excludes: `'the name'`, `'a.b'`, and anything containing a character outside the bare set.

**A `.` in a key is an error unless the key is quoted.** `example.com: 1`, `socket.io: '^4'`, `3.14: 'x'`, and `a.b: 1` are all errors, and so is a `.` after a quoted key, as in `'a'.b: 1`. A reader should suggest quoting the key, as in `'example.com': 1`, or nesting with braces, as in `a: {b: 1}`. JSON reads a `.` in a key as a character, and TOML and HOCON read it as a path, so either reading silently surprises the readers of the other. Host names, package names, file names, IP addresses, and versions are common map keys, and the path reading turns each of them into nested objects without a word, which is principle 1's problem moved from values to keys. The character reading has the mirror trap for anyone who writes `logging.level` and expects a path. Refusing both costs two quotes. The [FAQ](faq.md#why-no-dotted-keys-as-in-ab-1) says why SOML has no dotted keys.

Duplicate keys are an error. Uniqueness is decided on the **decoded string value** of the key, so `a`, `'a'`, `"a"`, and `"\u{61}"` are all the same key, and no two of them may appear in one object. That is why the rule is stated on the decoded value and not on the source text, which differs for all four.

No Unicode normalisation is performed. A composed string and the same string in decomposed form are different keys, and a reader that normalised them would silently merge two keys an author wrote deliberately.

The same is true of invisible characters. A quoted key may contain one, such as U+200B, so `'a'` and a quoted `a` followed by U+200B look the same and are two different keys. The format permits this because a quoted key is a string, and a string can contain such a character. Warning about a key that looks like another key is a job for a linter, not for the parser.

## Strings

`'...'` is literal: no escapes at all, and it ends at the next `'`. `"..."` is escaped. Both are single-line, so neither may contain LF or CR. Neither may contain a raw control character other than tab (see Encoding and newlines), so a control character in a value, other than CR, which is not representable, is written as an escape in `"..."`.

**The two quotes are not a style choice.** To a JavaScript or Python reader they look like one, and for nearly every string they give the same value. They differ only when the content has a `\`, and there the split puts the trap on the rare side. A Windows path or a regex pasted into the default `'...'` is correct. In an escaped string it is a common reason a config file fails to load. A `\n` meant as a newline in `'...'` shows up as a visible `\n`, and most other crossed mistakes, such as `"C:\Users"` or `'don\'t'`, are errors. This is the rule in POSIX shell, TOML, and YAML, where `''` writes a quote. Perl, Ruby, and PHP are close, but their `'...'` still treats `\\` and `\'` as escapes.

The escapes are `\\`, `\"`, `\n`, `\t`, and `\u{…}`. There is no `\/`, no `\x`, no `\v`, no `\0`, and no `\'`, because `'` needs no escaping. Any other character after a `\` is an error, so `"\q"` is a mistake rather than a literal `q`. In a `"""` block, a `\` at the end of a line is an error too, so there is no line continuation.

**There is one kind of Unicode escape, and it has exactly one spelling.** Inside the braces go one to six lowercase hexadecimal digits, with no leading zero, naming a Unicode scalar value other than U+000D:

```
\u{0}      \u{e9}      \u{1f600}
```

So each of these is an error: `\u{E9}` and `\u{1F600}` for the uppercase digit, `\u{0041}` for the leading zero, and `\u0041`, the four-digit form used by JSON, which is not an escape here at all. There is also no surrogate pair to write, because the escape names a scalar value and a surrogate is not one, so `\u{d800}` is an error.

There is no `\r`, and `\u{d}` is an error, because a carriage return is not representable anywhere in a SOML document. `\n` produces a line feed inside a value, and it does not affect line endings, which are always LF in a file.

The single spelling is on purpose. An escape that has one spelling never makes a reader consider another, and no implementation has to choose one. Canonical form writes `\u{…}` only for a control character, and in the same spelling. Lowercase is the choice because the escape sits inside quoted text rather than standing alone the way a number does, and because pinning a case is the part that matters: either case would do the job, so the format picks one and never asks a reader to consider the other.

A string is a sequence of Unicode scalar values with one exclusion: U+000D, a carriage return, is not representable. A lone surrogate is not a scalar value, so it is also an error, whether written directly or escaped. A noncharacter is a scalar value, so it is permitted, and it is written literally in canonical form.

Noncharacters are not rejected, although I-JSON rejects them, because that rule would buy very little and cost a 66-code-point exception to the simplest possible statement of what a string is. Unicode also requires a noncharacter to survive an encoding conversion unharmed, so a format that refused one would be stricter than the platform it runs on.

`'''...'''` and `"""..."""` are block strings. They follow Swift's dedent rule, except that blank lines are treated differently: here a line of only spaces and tabs is blank, and blank lines at the start and end are discarded, where Swift keeps both as content. The rules:

- The opening delimiter must be followed directly by a newline. Anything else on that line is an error, including trailing spaces, tabs, and a comment.
- Content begins on the line after the opening delimiter and ends on the line before the closing delimiter, so the value starts and ends with real content rather than a line break.
- The closing delimiter's indentation, meaning the spaces and tabs before it on its line, is stripped from the start of every content line. Indentation is compared here as raw characters, so one tab is not equal to four spaces, and a document should use the same style on both lines. A content line that does not begin with exactly the closing delimiter's indentation, character for character, is an error. A blank line, meaning one that is empty or holds only spaces and tabs, is exempt: it needs no indentation, and it becomes an empty line in the value.
- Blank lines directly after the opening delimiter and directly before the closing delimiter are discarded. Blank lines between content lines are kept, as empty lines. So a `'''` block cannot hold a line of only spaces and tabs, and a `"""` block writes one with escapes, such as `\t`.
- A `'''` block is literal. A `"""` block accepts the same escapes as `"..."`.
- The block ends at the first line that holds, after zero or more spaces and tabs, a run of exactly as many of the opening quote character as the opening delimiter. A longer run is content, and so is a run of the other quote character. So if the content must contain a line that begins with that run, use a longer delimiter: `''''` opens a block that four quotes close.
- That run is the closing delimiter. Normal tokenisation resumes directly after it, so a comma, a closing bracket, or a comment may follow on the same line. Inside `{}` and `[]`, the line break after it separates the block string from the next member or item, as after any other value:

```
pool: {
	description:
		'''
		Connections are reused.
		'''
	size: 4
}
```

## Numbers

An int is a decimal run of digits with an optional leading `-`, or a `0x`, `0o`, or `0b` prefix followed by at least one digit of that radix, with `_` permitted between two digits. So `0x`, `0b2`, `0o8`, and `0x_FF` are errors. Prefixes are lowercase, and the hexadecimal digits `A` to `F` are **uppercase**, so it is `0xFF` and never `0xff` or `0XFF`. The range is int64, and a value outside it is an error rather than a silent float.

**An implementation must represent every int64 value exactly.** That is a requirement on the implementation, not a licence to reject a document. An implementation that cannot hold a large integer exactly is not conforming, because the alternative is that two conforming implementations accept different sets of documents, which is the failure this format exists to prevent.

**An alternate radix is written without a sign.** So `0xFF`, `0o644`, and `0b1010` are values, and `-0xFF`, `-0o644`, and `-0b1010` are errors.

The asymmetry with decimal is deliberate, and it follows from what each form is for. A decimal literal states a **quantity**: a count, an offset, a threshold, a size. Quantities have signs, so `-30` is meaningful and unremarkable. An alternate radix states a **pattern**: a bit mask, a set of flags, a file mode, a byte. A pattern has no sign, and `-0b1` is a question rather than a value, because the answer depends on a width this format does not fix, so it reads as two's complement when it may have been a negation. With no sign, a pattern says exactly one thing.

An alternate radix has the same int64 range as decimal, so a pattern can use 63 bits. `0x7FFFFFFFFFFFFFFF` is the largest, and a 64-bit pattern with the top bit set, such as `0xFFFFFFFFFFFFFFFF`, is an error. That is a real limitation, and it is accepted because the alternative is the two's complement reading above: the same 64 bits would be a negative int to one reader and a large unsigned value to another. Write a full 64-bit pattern as a string.

The C family allows a sign on any radix because there a literal is a token and the sign is a unary operator applied to it. SOML has no operators, so a sign is part of the literal or it is nothing, and the only useful reading of a pattern is the unsigned one.

Leading zeros are errors in the decimal form, so `0.5` is fine and `00` is not, and `-0` is an error, because an int has no negative zero, so a `-` on zero can only be a mistake. The integer part of a float follows the same rule, so `00.5` and `01e2` are errors. An exponent follows it too, so `1e5` is valid, `1e05` is an error, and `1e-0` is an error because the exponent zero is written `e0`. `_1`, `1_`, and `1__0` are errors. After a radix prefix, leading zeros are allowed, so `0x00FF` is valid: a fixed width is what makes a byte pattern legible.

The uppercase rule is a readability rule. Hexadecimal is written uppercase wherever it is read as bytes, as in `#FF8800`, `FF:FF:FF`, and a memory dump, so `0xFF` reads correctly at a glance while `0xff` reads like something a tool lowercased on its way past.

Note that case is fixed per construct rather than forced to one case everywhere. A hexadecimal integer is uppercase because that is how hex reads when it stands alone. A `\u{…}` escape is lowercase because it sits inside quoted text. What matters is that each is pinned to one case, so there is nothing to normalise and nothing for two implementations to disagree about.

A float is an IEEE 754 binary64 value written as a decimal number with a fractional part, an exponent, or both, or as `infinity` or `-infinity`. Underscores follow the same rule as for ints.

A leading `.` and a trailing `.` are errors, so `.5` and `5.` are not numbers.

A `+` sign is an error anywhere in a number, on the body and in an exponent alike. A `-` means negative and its absence means positive, for the number and for its exponent, so `-1e-10` is a negative number with a negative exponent and no other combination needs a spelling of its own. A `+` marks a sign that is already the default: it tells a reader nothing the value did not already say, and it would give one exponent two spellings. That is one rule about `+` rather than one rule per position.

An exponent marker is a lowercase `e`, so `1E10` is an error. The case is pinned for the same reason every other case here is: one spelling means there is nothing to normalise and nothing for two implementations to disagree about.

`infinity` and `-infinity` are spelled out rather than abbreviated as `inf`, because a file is read far more often than it is written, and the full word needs no explanation from a reader. They are lowercase like `true`, `false`, and `null`, so every keyword has one case. There is no capitalised form, such as the `Infinity` of JavaScript and JSON5, and no abbreviated one. The extra characters cost nothing, because the format accepts one spelling either way.

**There is no `nan`.** Infinity earns its place here because it says something concrete about a bound: `limit: infinity` means no upper bound, and `-infinity` means no lower bound. It compares and orders normally. NaN is different in kind. It describes nothing; it reports that a computation failed to produce a meaningful number, and this format performs no computations. Where a value is unknown or absent, the format already says so more clearly with `null`, and spelling that as `nan` would blur "there is no value here" together with "this is an IEEE exceptional result".

It would also cost more than one token. IEEE 754 has many NaNs: quiet and signaling, with payloads and a sign bit. Collapsing them into a single `nan` value means the format discards floating-point information on the way in, and preserving them would put a payload model into the syntax. On top of that, IEEE says a NaN is not equal to itself, so the format would have to choose between copying that, which makes two identical documents unequal and breaks hashing that relies on equality, and overriding it, which means `nan` was never really IEEE NaN. Every reader, every schema, every range check, every sort, every hash, and every conversion to JSON would then need a NaN policy of its own, and implementations would disagree about it.

The strongest case for `nan` is scientific data, where a sequence such as `[1.2, 1.4, nan, 1.8]` may already hold a NaN in memory. But this format is not a lossless dump of a runtime's state. It caps an int at int64, has no binary type, has no arbitrary-precision number, and preserves no payloads and no widths. It is allowed to choose a cleaner abstract model than the machine underneath it.

**Being representable by IEEE 754 is not by itself a reason to be representable here.** The format carries the values that are useful and have clear meaning, not every state a processor register can hold.

`1` and `1.0` are different values of different types, and that is the point.

An int is a count, an index, a port, a byte count, or an identifier. A float is a measurement. `replicas: 3` and `threshold: 3.0` say different things, and this format makes the difference semantic rather than cosmetic: `3` is an int and `3.0` is a float, and they are still different after parsing and after a round trip. That buys five things.

- **The type survives.** With one number type, whether `1` and `1.0` remain distinguishable after parsing and reserialisation is up to the implementation. Here it is not: they are different values, and a reader that conflates them is not conforming.
- **Exact integers stay exact.** An int64 never silently becomes a different number, which is what happens in JSON today: `9007199254740993` is exact in Python and becomes `9007199254740992` in JavaScript, and neither side reports anything.
- **The model maps onto native types.** Swift has `Int64` and `Double`, Rust `i64` and `f64`, Go `int64` and `float64`, Java and C# `long` and `double`, PHP `int` and `float`, and Lua an integer subtype and a float subtype. A model that matches the languages reading it needs no translation table.
- **Mistakes become detectable.** If a schema wants an integer and someone writes `workers: 4.0`, a validator can reject it instead of having to decide whether a mathematically integral value is semantically an integer.
- **It follows the rule the format is built on.** Type comes from syntax, never from content. One number type forces a reader to guess whether `4.0` was meant as a count.

**The cost is real, and it is a requirement rather than a limitation.** An implementation must represent every int64 exactly. Most runtimes have a type for that. JavaScript is the awkward case, where `Number` cannot hold every int64 and an implementation therefore needs `BigInt` or another exact integer representation. What an implementation must not do is refuse the document, because refusing would mean two conforming implementations disagree about which documents are valid.

KDL is often raised against this, since it has one logical number type and leaves representation to implementations. But KDL reserves the type annotations `(i8)`, `(i16)`, `(i32)`, `(i64)`, `(i128)`, `(f32)`, and `(f64)`, which is an admission that applications still need the distinction. KDL pushes it out of the data model and into an annotation that a reader may ignore. Putting it in the value model is better, because an annotation can be ignored and this cannot.

The value of a float is one of: a finite IEEE 754 binary64 value, positive infinity, or negative infinity.

A value that is mathematically zero is zero, whatever its sign. `0.0` and `-0.0` are the same value, and the sign of a zero is not part of this format. IEEE 754 distinguishes the two, and SOML does not, for the same reason it declines NaN: no author writes a signed zero on purpose, and every reader who meets one has to look up what it means. An implementation may carry the sign through its own arithmetic, but it must not treat the two as different values, and it writes both as `0.0`. A reader still accepts `-0.0`, unlike the int `-0`, because programs write it: IEEE 754 has a negative zero, and Python's `json.dumps(-0.0)` gives `-0.0`. An int has no negative zero, so `-0` stays an error, although some JSON writers, such as Go's `encoding/json` and Swift's `JSONEncoder`, write a float negative zero as `-0`.

A decimal literal is converted to binary64 with round-to-nearest, ties-to-even, which is the IEEE default. A literal that rounds to an infinity under that rule, such as `1e999`, is an error rather than an infinity, because `infinity` is the explicit spelling of that value. So `1.7976931348623158e308` is valid and reads as the largest finite value, and `1.7976931348623159e308` is an error. A literal that is not zero but rounds to zero, such as `1e-400`, is an error too, rather than a silent zero, because `0.0` is the explicit spelling of that value. A literal that rounds to a subnormal, such as `5e-324`, is valid, because its value is not zero.

## Canonical values

`true`, `false`, and `null`. Lowercase, and only these three spellings.

`owner: null` says that the member is present and its value is null, which is different from leaving the member out. The first is a value and the second is absence, and a format that cannot express both makes every consumer guess which one it received. The word is `null` rather than `nil` because `nil` commonly carries the second meaning, and this value is the first.

An `instant` is an ISO 8601 date and time with a mandatory offset, written bare so that it can never be confused with a string. The separator is an uppercase `T`, and the offset is either `Z` or `±HH:MM`. Lowercase `t` and `z`, the `±HHMM` form, and a date with no time are all errors.

A fractional second is permitted and is limited to at most nine digits, so the smallest representable difference is a nanosecond. A tenth digit is an error, even when it is zero, rather than a silent rounding. Unlike a duration's, an instant's fraction is limited by its digits, not by its value. An implementation must represent every instant in the range below exactly, to the nanosecond. The offset is source detail and not part of the value, so two spellings of one instant are the same value, which is why canonical form has a single form for both.

A lexical match is not enough. The components are range-checked, and the date must exist:

| Component | Range |
|---|---|
| year | `0001` to `9999` |
| month | `01` to `12` |
| day | `01` to the last day of that month, in the proleptic Gregorian calendar |
| hour | `00` to `23` |
| minute | `00` to `59` |
| second | `00` to `59` |

A leap second is not representable, so `60` is an error. The offset is `Z` or `±HH:MM`, with hours `00` to `23` and minutes `00` to `59`. `-00:00` is an error: RFC 3339 §4.3 uses it to say that the time in UTC is known but the offset to local time is unknown, and this format does not carry that distinction, because the offset is source detail rather than part of the value.

**The instant itself must also be in range after it is moved to UTC**, from `0001-01-01T00:00:00Z` to `9999-12-31T23:59:59.999999999Z`. So `0001-01-01T00:00:00+00:01` is an error even though every component is in range, because in UTC it falls in year 0000, and canonical form, which always writes UTC, could not write it.

There is no date-only form, because a date is not an instant. If you need a date, use a string.

A `duration` is a length of time: one or more parts, each a decimal number followed by a unit, with an optional leading `-` that negates the whole value.

```
timeout: 30s
interval: 1h30m
grace: 1.5s
skew: -5m
```

The units are `h`, `m`, `s`, `ms`, `us`, and `ns`. They are lowercase, so `1H` is an error, and they appear in descending order, each at most once, so `30m1h` and `1m1m` are errors. A part has no cap of its own, so `90m` is valid and is the same value as `1h30m`. The number of a part is decimal digits with an optional fraction, by a float's rules: no leading zeros, `_` only between two digits, and a digit on each side of the `.`. It has no sign and no exponent. Only the last part may have a fraction, so `1.5h` and `1h1.5m` are valid and `1.5h30m` is an error.

The value is the exact sum of each part's number times its unit, so `1.5h` is the same value as `1h30m`. It must be a whole number of nanoseconds, so `0.5ns` and `1.0000000001s` are errors rather than a rounding. The value decides, not the number of digits, so `0.0000000001h` is valid. It is a signed count of nanoseconds in the int64 range, from `-9223372036854775808ns` to `9223372036854775807ns`, about 292 years either way, and a duration outside it is an error. The range applies to the signed value, so `-9223372036854775808ns` is valid. An implementation must represent every value in that range exactly. A `-` before a zero duration, such as `-0s`, is an error, so zero has no negative spelling, as with an int.

There is no day or week unit, because a civil day can have 23 or 25 hours across a daylight saving change. A fixed 24 hours is `24h`, and `1d` is an error.

## Arrays and objects

`[a, b, c]` and `{a: 1, b: 2}`. Inside a bracketed container, items are separated by a comma, by a line break, or by both, so a container written one item per line needs no commas:

```
ports: [
	80
	443
]
```

Commas and line breaks may be mixed, and a comma with line breaks after it is still one separator. A comma goes on the line of the item before it: only spaces, tabs, and comments may come between them, so a comma at the start of a line, as in the comma-first style, is an error. A line break separates items only outside a comment, as at the top level, so a line break inside a `/* */` comment does not. Two items on one line need a comma, so `[1 2]` is an error, and a comma with no item before it, as in `[,1]` and `[1,,2]`, is an error too. A trailing comma is allowed, on the line of the last item, so JSON and a one-line list written by a program stay valid.

The comma-first style is refused because a comma at the start of a line separates nothing that the line break before it does not already separate. It exists to keep a diff to one line in formats that forbid a trailing comma, and SOML has neither problem. With one place for a comma, a formatter and an editor have one layout to handle, and a reader never has to ask which item a comma belongs to.

A line break separates items because a line break between two values can only mean that they are two values. SOML has no operators, and no value that a following line can extend, because a block string ends only at its closing delimiter, so nothing that follows a line break can join the item before it. A line break after a `:` separates nothing, because a member is not complete until its value, so the value may begin on the next line. A value that is missing is still an error, because the next line then holds a closing bracket or another member, and a closing bracket is not a value, and the `:` after the other member's key cannot follow a value. Separating by line breaks also means that adding an item to a multi-line container changes one line, and that a program emitting a list never needs to know whether the item it is writing is the last one. Values of different types may be mixed in an array, so `[1, 'two', true, null]` is valid. Empty forms `[]` and `{}` are valid, and comments may appear inside them.

Nothing may appear between a key and its `:`, neither whitespace nor a comment, and one space is conventional after it. Whitespace and comments are permitted wherever the grammar writes `sp` or `ws`, which includes after a comma, before a comma on the same line, and between an opening delimiter and the first item.

**Nesting is limited to 100 levels.** Every array and every object is one level, including the document's own collection, whether or not it is written with braces. So `[]` has a depth of 1, and `a: [1]` and `{a: [1]}` both have a depth of 2. The depth belongs to the value, not to its spelling. A document deeper than 100 levels is an error, and a serializer must refuse a value deeper than 100 levels rather than write a document that no reader accepts.

The limit is exact, not a minimum. A reader must accept every document up to 100 levels and must reject every document deeper than that. JSON lets each implementation choose its own limit (RFC 8259 §9: "An implementation may set limits on the maximum depth of nesting"), and the defaults of common JSON parsers range from 64 levels (.NET) to 10,000 (Go) to no fixed limit (JavaScript's `JSON.parse`), so one document can be valid in one parser and invalid in another. The TOML development spec, after 1.1.0, recommends allowing at least 100 levels, which leaves the same disagreement above 100. A minimum would bring that disagreement into SOML, and it is the failure the int64 rule exists to prevent.

100 is far above any configuration file, and it is low enough that a recursive reader does not run out of stack, even in an unoptimised build. It is also the minimum that the TOML development spec recommends, and the default of protobuf's C++ implementation. The toml crate for Rust lowered its limit from 128 to 100 because 128 overflowed the stack in debug builds, and it now uses 80.

## Canonical form

Canonical form is one exact text for each value. Two conforming generators that write canonical form, given the same value, produce the same bytes, and the rules below determine those bytes completely. It is for hashing, signing, comparing, and caching.

A serializer that writes a file for people may keep the member order of its input and follow every other rule below. Sorted keys put `description` before `name` and `version` far down, and that order is noise to a person who reads the file. That output is not canonical form unless its input order is already sorted, so a serializer must also be able to write canonical form.

1. One member or item per line, indented with one tab per level, and a member is written as `key: value` with one space after the `:`. Values are never aligned into columns. The opening `{` or `[` of a non-empty object or array ends the line of its key or item, and the matching `}` or `]` begins its own line at the indentation of that key or item. There are no blank lines and no trailing whitespace.
2. No commas are written. Every member and item is on its own line, so a line break separates them, inside `{}` and `[]` as at the top level.
3. Members are sorted by key, comparing the key's Unicode scalar values in ascending order. That is the order of the keys' UTF-8 bytes, so a byte comparison such as `memcmp` sorts them. It is not the order of UTF-16 code units, which puts the characters above U+FFFF before U+E000 to U+FFFF. This is what makes two documents with the same members produce the same bytes. A formatter does not follow it, and it is the one rule that a serializer that writes for people may leave out.
4. A nested object is written with braces.
5. Objects and arrays span multiple lines, except that `[]` and `{}` are written on one line.
6. A non-empty top-level object is written without braces, and its entries begin at column 0. An empty top-level object is written `{}`, because a brace-less object needs at least one entry. A top-level array is written with brackets, like any other array: its `[` and `]` are at column 0 and its items are indented one tab.
7. Comments are never emitted.
8. A string uses `'...'` unless its content contains `'`, a tab, a LF, any other C0 control, or U+007F, in which case it uses `"..."`. A `\` or a `"` alone does not force the escaped form, because a literal string holds both as they are. A key is written bare when it is non-empty and every character is in the bare-key set, and otherwise as a string by the same rule.
9. Only these characters are escaped, in these forms: `\` as `\\`, `"` as `\"`, LF as `\n`, tab as `\t`, and every other C0 control or U+007F as `\u{…}` with lowercase hex digits and no leading zero. Every other character is written literally, including U+2028, U+2029, and a noncharacter. U+000D never appears, so it has no escape.
10. Multi-line content is written with `\n` inside a string. Block strings are never emitted.
11. An int is written as decimal digits, with no underscores and no prefix, and with `-` when it is negative. A float is written by the steps below. They are the layout of ECMAScript's `Number::toString`, which RFC 8785 also uses, with the digit choice of that algorithm's recommended alternative to its step 5, with `.0` added so that a float never reads as an int and with no `+` in an exponent.
	1. Zero is `0.0`, and `infinity` and `-infinity` are written as themselves. A negative value is written as `-` followed by its magnitude.
	2. Take the smallest k for which a k-digit integer s and an integer n exist such that s × 10^(n−k) reads back as the same binary64 value. If several pairs of s and n qualify, take the one for which s × 10^(n−k) is closest to the exact binary64 value, and if two are equally close, the one whose s is even.
	3. If k ≤ n ≤ 21, write the k digits of s, then n − k zeros, then `.0`: `1.0`, `100000000000000000000.0`.
	4. If 0 < n < k, write the first n digits, a `.`, and the remaining k − n digits: `1.5`, `3.14`.
	5. If −6 < n ≤ 0, write `0.`, then −n zeros, then the k digits: `0.5`, `0.000001`.
	6. Otherwise, write the first digit, then a `.` and the remaining digits when k > 1, then `e`, then n − 1 as a decimal int: `1e21`, `1.5e300`, `1e-7`, `5e-324`.
12. An instant is normalised to UTC and written with `Z`, with the fractional part omitted when it is zero and otherwise written with no trailing zeros.
13. A duration is written as `-` when it is negative, then the hours and the minutes of its magnitude, each left out when it is zero, then its seconds with their fractional part, left out when both are zero unless the whole duration is zero, with no underscores. Hours, minutes, and whole seconds are written like a decimal int, so with no leading zeros. Minutes are below 60, and seconds are below 60. The fractional part is written like an instant's: omitted when it is zero, and otherwise with no trailing zeros. So `90m` is written `1h30m`, `1500ms` is written `1.5s`, `250us` is written `0.00025s`, and zero is written `0s`.
14. The file is UTF-8, LF only, with no BOM, and ends with exactly one LF. A document always contains a value, so an empty file is not canonical.

Canonical form is a promise about output, not about input. A file you edit by hand may use any legal spelling, block strings, comments, and any indentation, and it is still a conforming SOML document.

## Formatting

Canonical form and formatting are two jobs.

**Canonical form** operates on a value and normalises everything, because a value has no author. It is for hashing, signing, comparison, and caching. It never contains comments, because a comment is not part of a value.

**Formatting** operates on the document someone wrote, and its job is layout alone. It preserves every choice the author made about content:

1. Comments, in place. A comment on its own line stays on its own line, and a comment at the end of a line stays at the end of that line, except where layout rule 4 below moves one when its line is split or emptied.
2. Member order, as written.
3. Number and duration spelling. `0xFF` stays hexadecimal, `0o644` stays octal, `1_000_000` keeps its separators, and `90m` stays `90m`.
4. String spelling. A literal string stays literal, and a block string stays a block string.
5. Structure. A brace-less top level is not given braces.

It normalises only layout:

1. Indentation, to one tab per level. A value on the line after its key, the comments on the lines between them, and the value's closing bracket are one level deeper than the key. A block string's opening delimiter, its content, and its closing delimiter have one indentation: one level deeper than its key for a member, and the item's own for an array item. Every content line keeps its indentation relative to the closing delimiter, and a blank line in it stays as it is, so the value does not change. The lines of a `/* */` comment after its first are not re-indented.
2. Line breaks, so that every member and every array item of a container that spans lines is on its own line, and its brackets are placed as in canonical form rule 1. A container whose opening and closing brackets are on one line stays on one line, with a comma between its members or items, as in `ports: [80, 443]`. A value begins on the line of its key, except a block string, which begins on the next line, and a value with a comment between it and its key, which stays on the line it is on. No blank lines come between a key and its value.
3. Commas, which are removed from a container that spans lines, because every member and item there is on its own line. In a container on one line, only the comma after the last member or item is removed.
4. Comments on a line that the formatter splits or empties. A comment stays after the token before it, except that a comment between an opening bracket or a comma and the member or item after it on the same line stays before that member or item. In a container that spans lines and holds only comments, a comment on the line of the opening bracket stays there, and the closing bracket begins its own line.
5. Spaces, so that one space separates the tokens and comments on a line wherever the grammar allows whitespace, as in `key: value # comment`, except that none comes before a comma, none is directly inside the brackets of a container on one line, as in `[1, /* note */ 2]`, and none is inside an empty `[]` or `{}`. A container that holds only comments is not empty.
6. Trailing whitespace, which is removed, and runs of blank lines, which collapse to one, also inside a `/* */` comment. Blank lines at the start and end of the file, and directly inside a bracket, are removed, and the file ends with one LF. None of this applies to the lines inside a block string, because they are content, and a trailing space there can be part of the value.

A file is "already formatted" when it is byte-identical to its formatted form.

**One line or several is the author's choice**, as a blank line between members is. A short list such as `ports: [80, 443]`, or a row of a matrix, reads best on one line, and a long one reads best with one item per line. A rule about width cannot tell them apart without a width setting and a way to measure text, and then "already formatted" would depend on a tool's settings and its Unicode tables. A trailing comma cannot carry the choice either, as it does in Black and zig fmt, because the formatter removes the commas of a container that spans lines. A line break survives formatting, so it is the signal, as it is in elm-format, gofmt, and Ormolu. To split a container, put a line break anywhere inside it. To join one, put it on one line. The formatter never joins the lines of a container that has members or items, and no comment directive changes how it lays out a node. The cost is that a long container that its author wrote on one line stays on one line, and a change to one of its items changes that whole line.

These rules are normative. A formatter must accept exactly the documents that a reader accepts, and it must give exactly the formatted form that the rules above describe. No option may change its output, so two conforming formatters give the same bytes for one document, and "already formatted" means the same thing to every tool. An implementation does not need a formatter to be a conforming reader or serializer.

**The line between those two lists is the whole point.** A formatter that normalised string, number, and duration spelling would turn `0o644` into `420`, `90m` into `1h30m`, and a block string into `"...\n..."`, destroying every reason the author chose the syntax. For a format whose premise is human authoring, that is the wrong trade. A formatter decides where the line breaks go. It does not decide that the author should have written something else.

The split exists because the two goals conflict. A configuration file's member order and its comments are human decisions that a diff should preserve, and neither belongs in a hash. Using one procedure for both would force the formatter to delete the thing the user wrote it for.

**What the pair buys.** From canonical form, a content hash that is stable across languages and tools, so a value can be signed, cached, or compared by digest. From the formatter, a diff that changes one line when you change one value, and a definition of "this file is already formatted" that does not depend on a formatter's heuristics or its version number.

Neither half is new on its own. RFC 8785, the JSON Canonicalization Scheme, fixes number spelling, string escaping, and member order so that equivalent JSON hashes identically, and SOML's canonical form does the same job for a richer value model. YAML 1.2 specifies a canonical form for scalar values only and leaves layout to whoever wrote the file. What no format in this family specifies is **both** halves: canonical bytes for a value, and a normative layout for a hand-written document. That pair is the claim.

## Editing

A tool that changes one value in a document, such as a command that sets or removes one setting, does a third job. It changes only the text of the members and items that it adds, replaces, or removes, and it keeps the layout of the rest, including comments and commas, except as the rules below state, so that its diff shows the change and nothing else.

**New text.** A new value is written as a serializer that writes for people writes it, at the indentation of its line, so with braces and without block strings. A value that it adds or replaces in a container that stays on one line is written on one line. A container stays on one line when its brackets are on one line and something other than spaces and tabs is between them, as in `[1, 2]` and `[/* note */]`, or when it is inside a container that stays on one line.

**Comments.** A member or an item owns these comments: the comments after it on its line, before its comma, or after its comma when nothing else follows on that line, and the block comments before it on its line, back to the comma or bracket before it. So in `[1 /* a */, /* b */ 2 /* c */]`, `1` owns `/* a */`, and `2` owns `/* b */` and `/* c */`. A comment on a line of its own belongs to no member or item. In a formatted document, these are the comments that layout rule 4 keeps with it. In one that is not, the list decides: in `[1, 2, /* note */]`, the closing bracket follows `/* note */` on the line of the trailing comma, so `2` does not own it, although the formatter writes it after `2` when it removes that comma.

Commas and comments follow from that:

1. A new member or item goes on a line of its own, without a comma, after the last one and the comments that it owns, so before a comment on a line of its own that follows them. In a container with no members or items, it goes on a line of its own between the brackets, unless the container stays on one line: then it goes before the closing bracket, so `[/* note */]` becomes `[/* note */ 1]`, and `[1, []]` becomes `[1, [2]]`. The new item then owns that comment, so removing it again gives `[]`. An empty `[]` or `{}` says nothing about layout, because the formatter writes every empty container that way, so `deps: {}` gets its first member on a line of its own. When the one before it is followed on its line by something other than its comma and comments, as by the `}` in `{a: 1}`, the new one goes on that line too, after a comma, and it also has a comma after it when the one before has one. So `{a: 1}` becomes `{a: 1, b: 2}`, `[1, 2 /* note */]` becomes `[1, 2 /* note */, 3]`, and `[1, 2,]` becomes `[1, 2, 3,]`.
2. A removed member or item takes the comments that it owns and its comma with it, which is the comma after it. When nothing else is on its lines, its lines go too, and so does one blank line next to them that would otherwise be left next to another blank line, directly inside a bracket, or at the start or end of the document, the one before them when there is a choice. Removing every member or item of a container closes it up to `[]` or `{}`, unless a comment that none of them owned is left inside, such as one on a line of its own, or one after the opening bracket on its line, as in `[ # note`. Removing the only member of a document without braces leaves `{}`, because a document is never empty, and the new text keeps the comments that the removed member owned, so `a: 1 # note` without `a` becomes `{} # note`.
3. When the removed member or item is the last one in its container and has no comma after it, it takes the comma directly before it instead, when only spaces and tabs are between that comma and the comments that it owns. So `[1, 2]` without `2` becomes `[1]`, and so does `[1, /* note */ 2]`.
4. Every other comma stays as it is. An edit never adds a comma to a member or an item that it does not change, except as rule 1 states, and it never removes one, except as rule 3 states. So a comma before a removed last item stays when a line break is between them, which leaves a trailing comma, and that is valid:

```
ports: [
	80,
	443
]
```

```
ports: [
	80,
]
```

A formatter removes that comma, and an edit leaves it, because an edit does not change layout that it was not asked to change.

**Paths that lead nowhere.** A change whose path does not fit the document is an error, because the tool's picture of the document is wrong: a key where an array is, an index where an object is, a path that goes through a value that is neither, a new item at an index past the end of its array, because the item before it would be missing, and an index below a value that does not exist, because a missing value is made as an object. A removal whose path fits the document but leads to nothing changes nothing, and it is not an error: a missing member, a missing object or array on the way, and an index at or past the end of its array. Removing means that the value is not there afterwards, and it is already not there, so removing the same path twice is safe. A tool tells its caller whether a removal removed something, so that a caller who expected a value can notice that it was missing.

These rules are normative for every tool that changes a value in a document, and an edit to a formatted document gives a formatted document. What they do not decide is left to the tool, as long as the result is a valid document with the right value, such as the whitespace around a removed member or item in a layout that the formatter never writes. The edit cases of the [conformance suite](conformance) fix the result of the common changes and which paths are errors, so tools agree on them. Which changes a tool offers, and how it reports an error, are its own decision.

## Grammar

The grammar has two layers: a lexical layer that produces tokens, and a syntactic layer that arranges them. The split is not cosmetic. A single layer with ordered alternation has prefix problems, because `'''` also begins a valid `'...'` literal, `1.0` and `1h` also begin with a valid int, `1.5s` begins with a valid float, and an instant also begins with four digits. A lexer with longest match removes all of them at once, and it is what an implementation would do anyway.

The notation is ABNF (RFC 5234) with these differences: quoted literals are case-sensitive and may use either quote, `-` excludes what follows it and binds tighter than `/`, `…` is a range of characters, `U+` names a code point, and a rule written in words, such as `EOF` and `scalar`, means what it says.

The grammar decides the shape of a document and nothing more. The ranges of ints, floats, `\u{…}` escapes, instants, and durations, the dedenting of block strings, duplicate keys, and the nesting limit are decided by the sections above, and a document that breaks one of them is an error even though the grammar matches it.

**Lexical layer.** Longest match wins, and where two rules match the same longest string, the earlier rule wins. Which token rules apply depends on position. Key position is the start of the first entry of a brace-less object, and every place where the syntactic layer allows a `key` to begin. Because a document is always a collection, no place allows both a key and a value. In key position, `bare-key`, `literal`, and `escaped` replace the value token rules, and `punctuation` still applies; everywhere else, every token rule except `bare-key` applies. Whitespace and comments are not tokens. They are matched only where the syntactic layer writes `sp` or `ws`, so where it writes two tokens next to each other, as with a key and its `:`, nothing may come between them.

```
; whitespace
sp          = *( " " / tab / comment )                  ; no line break, except inside a /* */ comment
ws          = *( " " / tab / line-break / comment )

; lines and comments
line-break  = LF
comment     = "#" *( char - line-break )
            / "/*" comment-body "*/"

; tokens
bare-key    = 1*( letter / digit / "_" / "-" )
string      = literal-block / escaped-block / literal / escaped
keyword     = "true" / "false" / "null"
int         = "0"                                        ; so "-0" is not an int
            / [ "-" ] nonzero *( [ "_" ] digit )
            / "0x" hex-digit *( [ "_" ] hex-digit )      ; alternate radices take no sign
            / "0o" oct-digit *( [ "_" ] oct-digit )
            / "0b" bin-digit *( [ "_" ] bin-digit )
float       = [ "-" ] int-part ( "." digits [ exponent ] / exponent )
            / "infinity" / "-infinity"
int-part    = "0" / nonzero *( [ "_" ] digit )           ; no leading zeros
digits      = digit *( [ "_" ] digit )
exponent    = "e" ( "0" / [ "-" ] nonzero *( [ "_" ] digit ) )  ; no leading zeros, no "-0"
instant     = 4digit "-" 2digit "-" 2digit               ; the components are range-checked
              "T" 2digit ":" 2digit ":" 2digit           ; against the table under
              [ "." 1*9digit ]                           ; Canonical values
              ( "Z" / ( "+" / "-" ) 2digit ":" 2digit )
duration    = [ "-" ] 1*( int-part [ "." digits ] unit ) ; units descending, each at most once, a
                                                         ; fraction on the last part only, no "-" on
                                                         ; zero, a whole number of nanoseconds, and
                                                         ; range-checked
unit        = "h" / "ms" / "m" / "s" / "us" / "ns"
punctuation = "{" / "}" / "[" / "]" / ":" / ","

; strings
literal     = "'" *( char - "'" - line-break ) "'"
escaped     = '"' *( escape / char - '"' - "\" - line-break ) '"'
escape      = "\" ( "\" / '"' / "n" / "t"
                   / "u{" ( "0" / hex-nonzero *5hex-lower ) "}" )
literal-block = "'''" line-break block "'''"   ; the delimiter is three or more quotes
escaped-block = '"""' line-break block '"""'   ; and the closing run is the same length

; character classes and terminals
tab         = U+0009
LF          = U+000A
EOF         = end of file
letter      = "A" … "Z" / "a" … "z"
digit       = "0" … "9"
nonzero     = "1" … "9"
oct-digit   = "0" … "7"
bin-digit   = "0" / "1"
hex-digit   = digit / "A" … "F"
hex-lower   = digit / "a" … "f"
hex-nonzero = nonzero / "a" … "f"
scalar      = one Unicode scalar value
comment-body = the chars before the first "*/" that begins after the "/*",
               which may not contain "/*"
char        = scalar - control                           ; tab and LF are not in control
control     = U+0000 … U+0008 / U+000B … U+001F / U+007F ; includes U+000D
```

`block` is defined by a rule rather than by an expression, because it is delimited by a line rather than by a token. The opening delimiter is a run of at least three quotes, and the length of that run is the delimiter's length. The block ends at the first line that holds, after zero or more spaces and tabs, a run of exactly that many of the opening quote character, so a longer run is content; that run is the closing delimiter. Everything before it is content, and every content character is a `char` or a line break. Dedenting, blank lines, and escapes are then applied as the Strings section states. Normal tokenisation resumes after it, so a comma, a closing bracket, or a comment may follow the closing delimiter on the same line. A content run at the start of a line that is as long as the delimiter would end the block, which is why a block whose text must contain such a run needs a longer delimiter.

**Syntactic layer.**

```
document    = ws ( object / array / bare-object ) ws EOF
bare-object = sp entry *( entry-sep entry ) ws
entry       = key ":" ws value                         ; nothing between a key and its ":"
entry-sep   = sp 1*( line-break sp )

key         = bare-key / literal / escaped

value       = object / array / string / instant / duration / int / float / keyword
object      = "{" ws [ member *( item-sep member ) [ sp "," ] ] ws "}"
member      = key ":" ws value
array       = "[" ws [ value *( item-sep value ) [ sp "," ] ] ws "]"
item-sep    = sp "," ws / entry-sep                    ; a comma on the item's line, a line break, or both
```

The alternatives in `value` are a presentation choice, not an ordering rule, because a token-based reader dispatches on the token type rather than on the text.

Five notes, because these are where an implementer will stumble.

**Keys are lexed in key position, and that is the only context-sensitive rule.** In key position only the `bare-key`, `literal`, and `escaped` patterns apply, so a token that would otherwise lex as an instant, a duration, or a number is read as a key there. That is what makes `404: 'x'` and `2024-01-01: 'x'` work without quoting. Because a bare key may not contain a colon, a key that contains one needs quotes. The `:` follows the key directly, with no whitespace or comment between them.

**A key is a string.** Nothing turns a key into a number, a date, or a boolean. `404: 'x'` has the string key `404`, and an implementation must not resolve a key against the value types.

**Keywords are legal keys.** `true`, `null`, and `infinity` are all valid bare keys, so `true: 1` is a document with one member whose key is the string `true`. There is no ambiguity, because the key position rule applies.

**No lookahead.** A document's form is decided by its first character after whitespace and comments: `{` and `[` begin a collection, and everything else begins a brace-less object. Because a document is always a collection, no position exists where a key token and a value token compete.

**A scalar can be lexed as one run.** An int, a float, an instant, a duration, and a keyword hold only letters, digits, `_`, `.`, `:`, `+`, and `-`, and in a valid document none of those characters comes directly after one. So a reader may take the longest run of them and then decide which token it is. That accepts and rejects the same documents as longest match over the separate rules.

## Prior art

Every feature here has a source, and most were borrowed deliberately. This section exists so the design can be judged on its decisions rather than on false claims of novelty.

| Feature | Where it comes from | What SOML changes |
|---|---|---|
| Literal strings | POSIX shell, §2.2.2: "Enclosing characters in single-quotes ( `''` ) shall preserve the literal value of each character within the single-quotes." Named as a type in a config format by TOML 0.3.0, 2014 | Promoted to the default spelling, with `"..."` as the escaped form, so the choice between them carries meaning |
| Multi-line strings dedented by the closing delimiter | Perl 5.26, May 2017, whose here-doc `~` modifier strips what precedes the delimiter; Swift 4.0 in September 2017, SE-0168; C# 11. Kotlin is often credited but uses a different rule, the minimum indent of the content. Java 15, in JEP 378, lets the closing delimiter take part, but it strips the minimum indentation of the content lines and the delimiter line. YAML's block scalars do not use it either | Adopted, including the rule that the newline before the closing delimiter is not content. Blank lines are handled differently, so that an editor that strips trailing whitespace cannot change a value |
| Duplicate keys are errors | TOML: "Defining a key multiple times is invalid." YAML 1.2.2 §3.2.1.3: "A mapping's keys are unique if no two keys are equal to each other" | Decided on the decoded string value, so `a`, `'a'`, and `"\u{61}"` are one key. A key is never typed, so detection needs no type resolution |
| Separate int and float | TOML 1.0.0: "Arbitrary 64-bit signed integers (from −2^63 to 2^63−1) should be accepted and handled losslessly", and "If an integer cannot be represented losslessly, an error must be thrown". TOML 1.1.0 relaxed the first to a recommendation | Adopted, including the error rather than a silent conversion |
| One timestamp type | TOML split temporal values four ways in 0.5.0, 2018, with offset date-time being the instant | Kept the instant only, with a mandatory offset |
| Durations with unit suffixes | Go's `time.ParseDuration`, as in `1h30m` and `300ms`, over an int64 count of nanoseconds | Kept the units, the range, and fractions. Dropped `µs` and `μs`, `+`, `-` on zero, a unitless `0`, leading zeros, repeated or unordered units, a fraction before the last part, a fraction without a digit on each side of the `.`, and the silent truncation of a fraction finer than a nanosecond. Added `_` separators |
| Dashes in bare keys | XML 1.0, 1998, permits a hyphen in a name but not as the first character. TOML's allow-list arrived in 0.4.0, 2015, with no first-character rule. HOCON and HCL allow a dash inside a key | Adopted with no first-character rule, and a quoted-key fallback for everything else |
| Allowing a key to begin with a digit | JSON, because a name is always a string; TOML, whose spec prints `1234 = "value"` as valid; Java `.properties`, which has no first-character rule; the freedesktop INI dialect; Kubernetes ConfigMap keys. RFC 1123 relaxed the same restriction for host names and required implementations to support the looser form | Adopted. HOCON's restriction applies to unquoted string values, so that they cannot be read as numbers, and its keys may still begin with a digit. A key that is always a string has no such conflict |
| Underscore digit separators | Ada 83, 1983, whose grammar `digit {[underline] digit}` already enforced no leading, trailing, or doubled underscore. C++14, with `'` as the separator, and TOML restate that rule. Java and Python are looser: Java allows doubled underscores, and Python allows one after a base prefix | Adopted in the strict form. See the note below |
| `0x`, `0o`, `0b` integers | C for `0x` and for leading-zero octal; Perl 5.6 in 2000 for `0b`; Python's `0o` from PEP 3127, shipped in 2008 | Adopted, with leading zeros forbidden so that C's octal trap cannot recur |
| Rejecting a UTF-8 BOM | RFC 3629 §6: "A protocol SHOULD forbid use of U+FEFF as a signature for those textual protocol elements that the protocol mandates to be always UTF-8." ECMA-262 is the matching precedent, since `JSON.parse` throws a `SyntaxError` on one | Adopted, and stated explicitly rather than left silent the way TOML leaves it |
| Canonical serialization | RFC 8785, the JSON Canonicalization Scheme, for hashing and signing | Applied to a richer value model, with int and float and instant kept apart, and paired with a separately specified formatter that preserves the source |
| A nesting limit | RFC 8259 §9 lets a JSON implementation set one. The TOML development spec, after 1.1.0, recommends allowing at least 100 levels, after its parsers added limits against deep dotted keys | Made exact rather than a minimum or a choice, so every reader accepts the same documents |
| A short spec | JSON, RFC 8259, which states its goals as "minimal, portable, textual" | Adopted as a constraint rather than a boast |

**One pre-emptive defence, because a reviewer will raise it.** YAML 1.2 removed underscore separators in 2009, and its changelog says only: "Underlines `_` cannot be used within numerical values." So a configuration format rejected this feature six years before TOML 0.4.0 adopted it in 2015. YAML 1.1's rule was permissive, "Any “_” characters in the number are ignored", once a number began with a digit, which made `4__2_` and `0x_FF_` valid numbers. SOML takes TOML's rule instead: an underscore must have a digit on each side. That admits exactly one interpretation, so the problem with YAML 1.1's rule does not apply.

**What is new here is the combination, not any part of it.** A JSON-shaped data model with JSON's strictness, no implicit typing, no significant indentation, the authoring features taken from YAML and TOML, every semantic defect decided rather than left open, and a pair of procedures: a deterministic serialization of a value, and a separately specified formatter that preserves what the author wrote. Neither half is new alone. YAML defines a canonical form for scalar values and RFC 8785 canonicalises JSON for signing. What is absent from the family is the pair.

## Next steps

The order matters. The specification is frozen last, not first, because every implementation written so far has found a place where this document disagreed with itself.

1. **Draft the specification.** This document.
2. **Write the conformance corpus alongside the grammar.** Roughly one hundred small files and their expected values, with one case for every ambiguity this document resolves, plus the expected canonical bytes for each valid case. The corpus is part of designing the grammar, not only a check on it afterwards: a rule that cannot be written as a test case is not yet a rule. This is the step every format compared in [comparison.md](comparison.md) skipped, and it is why YAML's own test matrix, in its newest snapshot from 2022, has PyYAML passing 329 of 402 cases.
3. **Write the reference parser.** A few hundred lines, run against the corpus.
4. **Write the canonical serializer and the formatter.** The serializer is the only component that must implement every canonical rule, so it is where they get tested.
5. **Fix every discrepancy in the specification.** Each disagreement between the document, the corpus, and the code is a defect in one of the three, and the document is the one to fix first.
6. **Freeze v1.**
7. **Only then write an independent second implementation**, against the frozen document and the corpus, not against the first implementation. A port written alongside the first one, such as the other implementations listed in the [readme](readme.md#implementations), finds defects in the document, but it does not count as independent.

A format with one implementation is a project, not a format. If a parser in a second language becomes worth someone else's time, it will happen. If it never does, that is the real answer to whether this design should exist.

## What SOML does not do, and why

Every omission here is deliberate. Each one is an answerable question rather than a gap.

| Not in the format | Why |
|---|---|
| Indentation as structure | Leading whitespace is not preserved by every tool that handles text, so a document must not depend on it. |
| Records in arrays without braces | Removing the braces does not remove syntax, it moves the object boundary to significant indentation, a record marker, or a terminator. The first breaks the rule above, and the others add a second object syntax. Braces use the ordinary object syntax everywhere. |
| Anchors and aliases | They make a document a graph rather than a tree, and unbounded alias expansion is a permanent denial-of-service surface. |
| Tags | A tag names a type, and a loader that resolves types freely will instantiate one from the file. |
| Implicit typing | A quoted string is never retyped by inspecting its content. Principle 1 is the basis of the whole design. |
| A schema in the syntax | A schema belongs in the tool that reads the document, where it can be versioned and tested separately. |
| Templating, imports, or computation | A document states values. Computation belongs in the tool, where it can be tested. |
| CRLF, and a carriage return anywhere | CR is the one character in text that exists only to be discarded. Accepting it adds a preprocessing step to every reader and a question to every diff. |
| `\r` as an escape | Refusing U+000D everywhere gives it one treatment rather than three. |
| NaN | It reports a failed computation, and this format performs no computations. It would also break equality and hashing. |
| `inf` | The full word needs no explanation, and a file is read more often than it is written. |
| A `+` sign | It marks a sign that is already the default. |
| Signed alternate radices | A pattern has no sign. `-0b1` is two's complement to one reader and a negation to another. |
| A date-only temporal type | A civil date is not an instant, and rendering one west of UTC gives the previous day. |
| Days or weeks in a duration | A day is not a fixed length. |
| A binary type | A string covers it, and a bespoke literal is a lexer path with no reader. |
| A version directive | Useful only if the format makes breaking changes, which it should not. |
| More than one document per file | One file, one document, so a file is addressable and a stream is a stream of files. |
| Multi-line plain strings | A block string is the multi-line form, and a second one would be a second spelling. |
| A second Unicode escape form | The braced form reaches the whole scalar range and gives an unambiguous boundary. |
| A quote-less string | It reintroduces implicit typing, which is what this format exists to avoid. |
| `nil` instead of `null` | `nil` means "no member here", which a missing member already says. `null` is a value. |
| Dotted keys | Braces already nest on one line, and a `.` that means a path silently nests keys such as `example.com` and `socket.io`. A `.` in a bare key is an error instead. See the [FAQ](faq.md#why-no-dotted-keys-as-in-ab-1). |
| A second comment syntax beyond `#` and `/* */` | Two forms cover a line and a region, which is all that is needed. |

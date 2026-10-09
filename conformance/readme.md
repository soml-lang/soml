# Conformance suite

The language-neutral test cases for SOML, as plain files, so that every implementation can run them. They live in the [`soml` repository](https://github.com/soml-lang/soml/tree/main/conformance), next to the [specification](https://github.com/soml-lang/soml/blob/main/spec.md), so a change to a rule changes its cases in the same commit.

- `valid/**/name.soml` must parse to the tagged value in `name.json`, and serialize in canonical form, with members sorted by key, to exactly `name.canonical.soml`. An implementation that has a formatter must also format it to exactly `name.formatted.soml`, and formatting that file again must give the same bytes.
- `invalid/**/name.soml` must be rejected.
- `edit/name.json` holds a formatted `document`, a `path` of keys and indexes, a tagged `value`, which is left out for a removal, and the `expected` document. An implementation that has an editor must give exactly `expected` when it sets `path` to `value`, or removes it. A case with `error: true` instead of `expected` has a path that does not fit the document, and the change must fail.

The expected values are tagged JSON, as in [toml-test](https://github.com/toml-lang/toml-test): a scalar is `{"type": "int", "value": "3"}`, and objects and arrays are plain JSON. The types are `string`, `int`, `float`, `bool`, `null`, `instant`, and `duration`. A float's value is its canonical spelling, including `infinity` and `-infinity`, an instant's is its canonical UTC form, and a duration's is its length in nanoseconds as a decimal int.

## Error positions

`invalid-reasons.json` gives the `line` and `column` where each invalid case fails, and the `reason` that the JavaScript reference implementation gives. It is informative, because the spec does not define error positions or messages. Lines and columns start at 1, and the column counts Unicode scalar values. An implementation should report the same position. The reason is reference wording, not a requirement.

The file is written by [`scripts/update-invalid-reasons.ts`](https://github.com/soml-lang/soml-javascript/blob/main/scripts/update-invalid-reasons.ts) in the JavaScript implementation, which expects the `soml` repository to be checked out next to it.

The errors that apply to every byte (see [Encoding and newlines](https://github.com/soml-lang/soml/blob/main/spec.md#encoding-and-newlines)) come before every other error, in this order: invalid UTF-8, then a BOM, then a raw control character, each at its first occurrence. So a reader that checks them in one pass before it parses reports the expected positions.

## File names

Case names differ in more than letter case, and none is a name that Windows reserves, such as `nul`, so the suite checks out on every file system, and Go can publish a module that contains it.

## Using the suite in an implementation

Keep a copy of this directory in the implementation, and do not edit it there. To update the copy, check out the `soml` repository next to the implementation and run:

```sh
../soml/sync-conformance.sh test/conformance
```

It replaces the directory with this one and writes the commit it came from to `commit` in it.

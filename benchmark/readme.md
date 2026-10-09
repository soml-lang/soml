# Benchmark fixtures

Realistic documents for benchmarks, as plain files, so that every implementation measures the same input and the numbers can be compared. They are not test cases, and an implementation does not have to use them.

There are three, for the three sizes that matter:

- `service` (3 KB): a hand-written service config, the size of most config files. It has comments, block strings, durations, an instant, and hex, octal, and underscored ints.
- `platform` (35 KB): the config of a self-hosted code-hosting platform, in the style of a large Helm values file. A quarter of its lines are comments, many of them commented-out settings, so it measures comment scanning and the formatter. It also has many durations, block strings, quoted keys, and digit keys such as `404`.
- `earthquakes` (733 KB): 986 earthquakes from the USGS feed, as GeoJSON. It is the large document, with about 2,000 instants, 7,000 floats, and ints and strings in every record.

The sizes are of the `.soml` files. Report the time for each fixture, not the throughput, because the formats do not have the same size for the same data.

`service` and `platform` were written for this repository, and `earthquakes` is made from public-domain data, so no fixture needs a license notice. A cost that the three do not stress, such as text that is not ASCII, is better measured by a small benchmark in the implementation.

## Formats

Each fixture is in SOML, JSON, and TOML, with the same data, so a benchmark can compare SOML with the JSON and TOML parsers of its language. The `.soml` files are the source. The `.json` and `.toml` files are written from them by [`scripts/update-benchmark-fixtures.ts`](https://github.com/soml-lang/soml-javascript/blob/main/scripts/update-benchmark-fixtures.ts) in the JavaScript implementation, which reads each file back and checks that it holds the same data. Do not edit them by hand.

Each format is written as a person writes it, with the layout of the SOML file, so that each parser reads the same data in about the same amount of text:

- A container on one line in SOML is on one line in JSON and TOML, and one that spans lines spans lines.
- TOML has the comments of the SOML file. JSON has no comments.
- A quoted key or string keeps its kind of quotes in TOML, which has the same literal `'...'` and escaped `"..."` strings.
- TOML has the same spelling of an int as SOML, such as `0x2000` or `100_000`, and JSON has it in decimal. A float has a fraction in all three, as in `180.0`, so a parser that keeps the difference gets the same types from SOML and TOML.
- An instant is an offset date-time in TOML and its ISO 8601 string in JSON, such as `"2026-09-19T14:00:00Z"`. A duration is its ISO 8601 string in both, such as `"PT55S"`, because neither has a duration.
- TOML has no null, so a member whose value is null is left out of the TOML.
- A multi-line object is a table in TOML, and an array of them is an array of tables, which TOML writes after the plain keys of their table.

## Sources

`earthquakes.soml` was made once from its source, and is the source now. It is the [USGS feed](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_week.geojson) of all earthquakes in the past week, as generated at 2026-10-10T16:27:54Z, with the newer half of its events, which the feed lists first. USGS data is in the public domain. A time is an instant, where the feed has milliseconds since 1970. A measurement, such as `mag`, is a float. A member whose value is null is left out, so that the TOML holds the same data.

## Using the fixtures in an implementation

Keep a copy of this directory in the benchmark of the implementation, and do not edit it there. Leave it out of the published package. To update the copy, check out the `soml` repository next to the implementation and run, for example:

```sh
rsync --archive --delete ../soml/benchmark/ bench/fixtures/
```

In the readme of the implementation, give one table near the end, with a row for each fixture, and a column for the time to read it with this implementation and with the most used JSON and TOML libraries of the language. Add rows for writing if the implementation has a writer, and say which machine the numbers are from.

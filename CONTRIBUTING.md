# Contributing

Bug reports and pull requests are welcome at https://github.com/beflagrant/windsock.
Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting bugs

Include the Ruby and Windsock versions, the `@theme` CSS that misbehaves (trimmed
to the smallest case you can), what you expected and what you got.

## Making changes

```
bin/setup
bundle exec rake        # tests + rubocop
bin/console
```

- Add a test for the change. `bundle exec rake` must pass.
- Add a line under `## [Unreleased]` in `CHANGELOG.md` for anything users would notice.
- Keep pull requests to one change each.

## Updating the bundled Tailwind theme

Copy `theme.css` from the `tailwindcss` npm package into `lib/windsock/tailwind/`,
update its `LICENSE` if it changed, and bump `Windsock::TAILWIND_VERSION`.

## Security issues

See [SECURITY.md](SECURITY.md). Don't open a public issue.

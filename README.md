# TableauPaginationExtension

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Coveralls][shield-coveralls]

- code :: <https://github.com/halostatue/tableau_pagination_extension>
- issues ::
  <https://github.com/halostatue/tableau_pagination_extension/issues>

A Tableau extension for paginating collection indexes (like posts or tags).

```elixir
config :tableau, TableauPaginationExtension,
  enabled: true,
  collections: [
    posts: [
      permalink: "/posts/:page?",
      layout: MySite.RootLayout,
      template: MySite.PostsPage,
      per_page: 5
    ]
  ]
```

## Installation

Add `tableau_pagination_extension` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tableau_pagination_extension, "~> 1.0"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

TableauPaginationExtension follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/tableau_pagination_extension
[hexpm]: https://hex.pm/packages/tableau_pagination_extension
[licence]: https://github.com/halostatue/tableau_pagination_extension/blob/main/LICENCE.md
[semver]: https://semver.org/
[shield-coveralls]: https://img.shields.io/coverallsCoverage/github/halostatue/tableau_pagination_extension?style=for-the-badge
[shield-docs]: https://img.shields.io/badge/hex-docs-purple.svg?style=for-the-badge
[shield-hex]: https://img.shields.io/hexpm/v/tableau_pagination_extension.svg?style=for-the-badge
[shield-licence]: https://img.shields.io/hexpm/l/tableau_pagination_extension.svg?style=for-the-badge

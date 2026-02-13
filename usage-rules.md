# TableauPaginationExtension Usage Rules

TableauPaginationExtension is a Tableau extension that automatically generates
paginated index pages for collections like posts, pages, tags, and custom data.

## Core Behavior

Splits large collections into multiple pages with configurable items per page.
Generates navigation metadata (page numbers, prev/next links) for building
pagination controls in templates.

## Configuration Format

```elixir
config :tableau, TableauPaginationExtension,
  enabled: true,
  collections: [
    posts: [
      permalink: "/posts/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.PostsPage,
      per_page: 10,
      sort: {:date, {:desc, Date}}
    ]
  ]
```

Each collection requires:

- `permalink` - URL pattern with `:page` or `:page?` placeholder
- `layout` - Layout module
- `template` - Template module with `template/1` function

Optional:

- `per_page` - Items per page (default: 10)
- `sort` - Sort configuration (default: `{:date, {:desc, Date}}`)
- `type` - Explicit type for handler selection
- `handler` - Explicit handler module
- `key_path` - Path to collection in token (default: `[collection_key]`)

## Permalink Patterns

### Optional First Page (`/:page?`)

```elixir
permalink: "/posts/:page?"
```

Generates:

- Page 1: `/posts` (no page number)
- Page 2: `/posts/2`
- Page 3: `/posts/3`

Use when first page should have clean URL.

### Required Page Number (`/:page`)

```elixir
permalink: "/posts/:page"
```

Generates:

- Page 1: `/posts/1`
- Page 2: `/posts/2`
- Page 3: `/posts/3`

Use when all pages should have explicit numbers.

### Explicit First/Rest

```elixir
permalink: [first: "/blog", rest: "/blog/page/:page"]
```

Generates:

- Page 1: `/blog`
- Page 2: `/blog/page/2`
- Page 3: `/blog/page/3`

Use for custom URL structures.

### Multi-Placeholder Patterns

For tag pages:

```elixir
permalink: "/tags/:tag/:page?"
```

For category pages:

```elixir
permalink: "/categories/:key/:page?"
```

The `:page` or `:page?` must be at the end of the permalink string.

## Type Inference

Collection keys automatically determine handler and default sort:

- `:posts` → List handler, sort by date descending
- `:pages` → List handler, sort by title ascending
- `:tag_index` → Tag index handler, sort by title ascending
- `:tag_pages` → Tag page handler, sort by date descending

Override with explicit `type:` or `handler:` option.

## Sorting Options

### Field Name (atom)

```elixir
sort: :title  # ascending by title
sort: :date   # descending by date (special case)
```

### Field with Direction

```elixir
sort: {:title, :asc}
sort: {:date, :desc}
sort: {:date, {:desc, Date}}  # with comparator module
```

### Extractor Function

```elixir
sort: {fn post -> String.length(post.body) end, :desc}
```

### MFA Extractor

```elixir
sort: {{MyModule, :extract_value, []}, :asc}
```

### Comparator Function

```elixir
sort: fn p1, p2 -> p1.title < p2.title end
```

### MFA Comparator

```elixir
sort: {MyModule, :compare_posts, []}
```

### No Sorting

```elixir
sort: false
```

## Template Variables

Templates receive these assigns:

- `@posts` - Items for current page (always named `posts` regardless of
  collection)
- `@page_number` - Current page number (1-indexed)
- `@total_pages` - Total number of pages
- `@prev_page` - Previous page number (nil if first page)
- `@next_page` - Next page number (nil if last page)
- `@first_page_url` - URL to first page
- `@prev_page_url` - URL to previous page (nil if first page)
- `@next_page_url` - URL to next page (nil if last page)
- `@last_page_url` - URL to last page

## Template Example

```elixir
defmodule MyApp.PostsPage do
  require EEx

  EEx.function_from_string(:def, :template, """
  <div class="posts">
    <%= for post <- @posts do %>
      <article>
        <h2><a href="<%= post.permalink %>"><%= post.title %></a></h2>
        <time><%= post.date %></time>
      </article>
    <% end %>
  </div>

  <%= if @total_pages > 1 do %>
    <nav class="pagination">
      <%= if @prev_page_url do %>
        <a href="<%= @prev_page_url %>">← Previous</a>
      <% end %>
      <span>Page <%= @page_number %> of <%= @total_pages %></span>
      <%= if @next_page_url do %>
        <a href="<%= @next_page_url %>">Next →</a>
      <% end %>
    </nav>
  <% end %>
  """, [:assigns])
end
```

## Collection Types

### Posts/Pages (List Handler)

Paginates simple lists:

```elixir
posts: [
  permalink: "/posts/:page?",
  layout: MyApp.RootLayout,
  template: MyApp.PostsPage,
  per_page: 10
]
```

Accesses `token.posts` by default.

### Data Collections (List Handler)

Paginates custom data:

```elixir
articles: [
  key_path: [:data, "articles"],
  permalink: "/articles/:page?",
  layout: MyApp.RootLayout,
  template: MyApp.ArticlesPage,
  per_page: 15,
  sort: :title
]
```

Use `key_path` for nested data like `token.data["articles"]`.

### Tag Index (Tag Index Handler)

Paginates list of all tags:

```elixir
tag_index: [
  key_path: [:tags],
  permalink: "/tags/:page?",
  layout: MyApp.RootLayout,
  template: MyApp.TagIndexPage,
  per_page: 50,
  sort: :title  # or {:count, :desc} for popularity
]
```

Each tag includes `:count` field with number of posts.

### Tag Pages (Tag Page Handler)

Paginates posts within each tag:

```elixir
tag_pages: [
  key_path: [:tags],
  permalink: "/tags/:tag/:page?",
  layout: MyApp.RootLayout,
  template: MyApp.TagPage,
  per_page: 20,
  sort: {:date, {:desc, Date}}
]
```

Requires `:tag` placeholder in permalink. Generates separate paginated pages for
each tag.

### Map Index (Map Index Handler)

Paginates map keys:

```elixir
category_index: [
  handler: MapIndexPager,
  key_path: [:categories],
  permalink: "/categories/:page?",
  layout: MyApp.RootLayout,
  template: MyApp.CategoryIndexPage,
  per_page: 30
]
```

### Map Pages (Map Page Handler)

Paginates each map value separately:

```elixir
category_pages: [
  handler: MapPagePager,
  key_path: [:categories],
  permalink: "/categories/:key/:page?",
  layout: MyApp.RootLayout,
  template: MyApp.CategoryPage,
  per_page: 15
]
```

Requires `:key` placeholder in permalink. Generates separate paginated pages for
each map key.

## Common Patterns

### Multiple Collections

```elixir
config :tableau, TableauPaginationExtension,
  enabled: true,
  collections: [
    posts: [
      permalink: "/posts/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.PostsPage,
      per_page: 10
    ],
    pages: [
      permalink: "/pages/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.PagesPage,
      per_page: 20,
      sort: :title
    ]
  ]
```

### Tag Pagination (Both Index and Pages)

```elixir
config :tableau, TableauPaginationExtension,
  enabled: true,
  collections: [
    tag_index: [
      key_path: [:tags],
      permalink: "/tags/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.TagIndexPage,
      per_page: 50
    ],
    tag_pages: [
      key_path: [:tags],
      permalink: "/tags/:tag/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.TagPage,
      per_page: 20
    ]
  ]
```

## Common Issues

1. **Missing `:page` placeholder**: Permalink must contain `:page` or `:page?`

2. **`:page` not at end**: Must be at the end of the permalink string

3. **Missing required placeholders**: TagPagePager needs `:tag`, MapPagePager
   needs `:key`

4. **Wrong collection path**: Use `key_path` for nested collections (e.g.,
   `[:data, "articles"]`)

5. **Template variable name**: Items are always in `@posts` assign, regardless
   of collection name

6. **Sort field doesn't exist**: Items with missing sort field sort
   unpredictably

7. **Invalid handler module**: Check module name and that it's compiled

## Extensibility

Create custom handlers by implementing `TableauPaginationExtension.Pager`
behaviour:

```elixir
defmodule MyApp.CustomPager do
  @behaviour TableauPaginationExtension.Pager

  @impl true
  def paginate(token, opts) do
    # Extract items from token
    # Sort items
    # Call Pager.build_pages(items, per_page, permalink, layout, template)
  end

  @impl true
  def validate_permalink(permalink) do
    # Optional: validate permalink requirements
    :ok
  end
end
```

Use with explicit handler:

```elixir
custom_collection: [
  handler: MyApp.CustomPager,
  permalink: "/custom/:page?",
  layout: MyApp.RootLayout,
  template: MyApp.CustomPage
]
```

## Resources

- [HexDocs](https://hexdocs.pm/tableau_pagination_extension) - Full API
  documentation
- [Tag Pagination Guide](https://hexdocs.pm/tableau_pagination_extension/paginating-tags.html) -
  Detailed tag pagination examples

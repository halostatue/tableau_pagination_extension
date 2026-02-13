# Paginating Tags

This guide shows how to create paginated tag pages using the tag-specific
handlers.

## Prerequisites

You must have the `Tableau.TagExtension` enabled and configured. This extension
creates `token.tags` which maps tag maps to lists of posts.

```elixir
config :tableau, Tableau.TagExtension,
  enabled: true,
  layout: MyApp.TagLayout,
  permalink: "/tags"
```

## Tag Index Pages

To create a paginated list of all tags (useful when you have many tags):

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
    ]
  ]
```

The default sort is alphabetical by tag title. To sort by most popular tags
first, use `sort: {:count, :desc}`.

### Template Example

The `@posts` value passed to the `TagIndexPage` is the keys of the tags map,
with a `:count` field containing the number of posts for that tag.

```elixir
defmodule MyApp.TagIndexPage do
  require EEx

  EEx.function_from_string(:def, :template, """
  <section>
    <h1>All Tags</h1>

    <ul class="tag-list">
      <%= for tag <- @posts do %>
        <li>
          <a href="<%= tag.permalink %>"><%= tag.title %></a>
          <span class="tag-count"> (<%= tag.count %> posts)</span>
        </li>
      <% end %>
    </ul>

    <%= if @total_pages > 1 do %>
      <nav class="pagination">
        <%= if prev_url = @prev_page_url do %>
          <a href="<%= prev_url %>">← Previous</a>
        <% end %>
        <span>Page <%= @page_number %> of <%= @total_pages %></span>
        <%= if next_url = @next_page_url do %>
          <a href="<%= next_url %>">Next →</a>
        <% end %>
      </nav>
    <% end %>
  </section>
  """, [:assigns])
end
```

## Per-Tag Post Pages

To create paginated pages for each tag's posts. Because it's a post collection,
the sort defaults to descending post date (`{:date, {:desc, Date}}`). The `:tag`
placeholder in the permalink is replaced with each tag's slug.

```elixir
config :tableau, TableauPaginationExtension,
  enabled: true,
  collections: [
    tag_pages: [
      key_path: [:tags],
      permalink: "/tags/:tag/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.TagPostsPage,
      per_page: 20
    ]
  ]
```

### Template Example

In addition to the normal `@posts` and pagination assigns, the `@tag` assign for
the tag being rendered is also available.

```elixir
defmodule MyApp.TagPostsPage do
  require EEx

  EEx.function_from_string(:def, :template, """
  <section>
    <h1>Posts tagged "<%= @tag.title %>"</h1>

    <%= for post <- @posts do %>
      <article>
        <h2><a href="<%= post.permalink %>"><%= post.title %></a></h2>
        <time datetime="<%= post.date %>">
          <%= Calendar.strftime(post.date, "%B %d, %Y") %>
        </time>
      </article>
    <% end %>

    <%= if @total_pages > 1 do %>
      <nav class="pagination">
        <%= if first_url = @first_page_url do %>
          <a href="<%= first_url %>">« First</a>
        <% end %>
        <%= if prev_url = @prev_page_url do %>
          <a href="<%= prev_url %>">‹ Previous</a>
        <% end %>
        <span>Page <%= @page_number %> of <%= @total_pages %></span>
        <%= if next_url = @next_page_url do %>
          <a href="<%= next_url %>">Next ›</a>
        <% end %>
        <%= if last_url = @last_page_url do %>
          <a href="<%= last_url %>">Last »</a>
        <% end %>
      </nav>
    <% end %>
  </section>
  """, [:assigns])
end
```

## Using Both Together

You can configure both handlers to create a complete paginated tag browsing
experience:

```elixir
config :tableau, TableauPaginationExtension,
  enabled: true,
  collections: [
    # List of all tags
    tag_index: [
      key_path: [:tags],
      permalink: "/tags/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.TagIndexPage,
      per_page: 50
    ],
    # Posts for each tag
    tag_pages: [
      key_path: [:tags],
      permalink: "/tags/:tag/:page?",
      layout: MyApp.RootLayout,
      template: MyApp.TagPostsPage,
      per_page: 20
    ]
  ]
```

This creates:

- `/tags` - First page of tag index
- `/tags/2`, `/tags/3`, etc. - Additional tag index pages
- `/tags/elixir` - First page of posts tagged "elixir"
- `/tags/elixir/2`, `/tags/elixir/3`, etc. - Additional pages for that tag
- Similar pages for each tag in your site

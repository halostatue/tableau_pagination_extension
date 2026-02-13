defmodule TableauPaginationExtension do
  @moduledoc """
  Tableau extension that generates paginated index pages for collections: posts, tags, and
  tagged posts.

  ## Overview

  This extension creates paginated index pages for Tableau collections (like posts or
  tags). It automatically splits large collections into multiple pages with configurable
  items per page and generates navigation metadata for building pagination controls.

  ## Configuration

  ```elixir
  config :tableau, TableauPaginationExtension,
    enabled: true,
    collections: [
      posts: [
        permalink: "/posts/:page?",
        layout: MyApp.RootLayout,
        template: MyApp.PostsPage,
        per_page: 10
      ]
    ]
  ```

  ### Configuration Options

  - `:enabled` (default `false`): Enable or disable the extension

  - `:collections`: A keyword list or map of collections to paginate. Each collection
    requires:

    - `:permalink`: URL pattern for the paginated pages (see Permalink Patterns below)
    - `:layout`: The layout module to use for rendering pages
    - `:template`: The template module containing a `template/1` function
    - `:per_page` (default `10`): Number of items per page
    - `:sort`: How to sort the collection before pagination. Defaults based on `:type`.
      See Sorting Collections below.
    - `:key_path`: Path to the collection in the token. Defaults to `[collection_name]`.
      For nested data, use a list like `[:data, "articles"]`.
    - `:type`: Collection type that determines handler and default sort. Inferred from
      collection key name if not specified. Built-in types:
      - `:posts` - List handler, sorts by date descending (default for unknown keys)
      - `:pages` - List handler, sorts by title ascending
      - `:data` - List handler, sorts by title ascending
      - `:tag_index` - Tag index handler, sorts by entry count descending
      - `:tag_pages` - Tag pages handler, sorts by date descending
      - `:map_index` - Map index handler, preserves order (no sort)
      - `:map_pages` - Map pages handler, sorts by date descending

  ### Permalink Patterns

  The `:permalink` option supports three formats:

  1. **Optional page suffix** (`"/posts/:page?"`):
     - First page: `/posts`
     - Subsequent pages: `/posts/2`, `/posts/3`, etc.

  2. **Required page placeholder** (`"/posts/page/:page"`):
     - All pages include the page number: `/posts/page/1`, `/posts/page/2`, etc.

  3. **Explicit first/rest** (keyword list):
     ```elixir
     permalink: [first: "/posts", rest: "/posts/page/:page"]
     ```

  ### Sorting Collections

  The `:sort` option controls how items are sorted before pagination. It uses
  `Enum.sort_by/3` or `Enum.sort/2` depending on the configuration.

  **Field-based sorting** (uses `Enum.sort_by/3`):

  ```elixir
  sort: :date                           # {:date, {:desc, Date}} - special default
  sort: :title                          # {:title, :asc} - default for non-date
  sort: {:title, :asc}                  # explicit field and direction
  sort: {:date, {:desc, DateTime}}      # with custom comparator module
  sort: {:title, &my_compare/2}         # with custom comparator function
  ```

  **Custom extraction** (uses `Enum.sort_by/3`):

  ```elixir
  sort: {&length(&1.tags), :desc}       # inline extractor function
  sort: {{Mod, :extract, []}, :asc}     # MFA extractor
  ```

  **Full object comparison** (uses `Enum.sort/2`):

  ```elixir
  sort: &Mod.compare/2                  # comparator function
  sort: {Mod, :compare, []}             # MFA comparator
  ```

  **No sorting**:

  ```elixir
  sort: false                           # preserve collection order
  ```

  The direction parameter accepts the same values as `Enum.sort_by/3`:
  - `:asc` or `:desc` (uses default comparator)
  - `{:asc, module}` or `{:desc, module}` (uses custom comparator like `Date`, `DateTime`)
  - A custom 2-arity comparator function

  Default sorting:
  - `:date` field defaults to `{:desc, Date}`
  - Other fields default to `:asc`
  - No `:sort` specified defaults to `{:date, {:desc, Date}}` for backward compatibility

  ## Template Usage

  The extension passes pagination data to your template through `assigns.page`:

  ```elixir
  def template(assigns) do
    posts = assigns.page.posts           # Items for this page
    page_number = assigns.page.page_number
    total_pages = assigns.page.total_pages

    # Page numbers (nil when not applicable)
    prev_page = assigns.page[:prev_page]
    next_page = assigns.page[:next_page]

    # Generated URLs (nil when not applicable)
    first_page_url = assigns.page.first_page_url
    prev_page_url = assigns.page[:prev_page_url]
    next_page_url = assigns.page[:next_page_url]
    last_page_url = assigns.page.last_page_url

    # Your template code here
  end
  ```

  ### Complete Example

  ```elixir
  defmodule MyApp.PostsPage do
    require EEx

    EEx.function_from_string(:def, :template, \"\"\"
    <section>
      <h2>All Posts</h2>

      <%= for post <- @posts do %>
        <article>
          <h3>
            <a href="<%= post.permalink %>"><%= post.title %></a>
          </h3>
          <time datetime="<%= post.date %>">
            <%= Calendar.strftime(post.date, "%B %d, %Y") %>
          </time>
          <div class="excerpt">
            <%= raw(post.excerpt) %>
          </div>
        </article>
      <% end %>

      <%= if @total_pages > 1 do %>
        <nav class="pagination">
          <%= if first_url = @first_page_url do %>
            <a href="<%= first_url %>" class="pagination-first">« First</a>
          <% end %>

          <%= if prev_url = @prev_page_url do %>
            <a href="<%= prev_url %>" class="pagination-prev">‹ Previous</a>
          <% end %>

          <span class="pagination-info">
            Page <%= @page_number %> of <%= @total_pages %>
          </span>

          <%= if next_url = @next_page_url do %>
            <a href="<%= next_url %>" class="pagination-next">Next ›</a>
          <% end %>

          <%= if last_url = @last_page_url do %>
            <a href="<%= last_url %>" class="pagination-last">Last »</a>
          <% end %>
        </nav>
      <% end %>
    </section>
    \"\"\", [:assigns])
  end
  ```

  ## Custom Collections

  This extension can paginate any collection available in the Tableau token. Built-in
  collections include `:posts` and `:pages`.

  For nested collections, use the `:key_path` option to specify the path:

  ```elixir
  collections: [
    articles: [
      key_path: [:data, "articles"],
      permalink: "/articles/:page?",
      sort: :title,
      layout: MyApp.RootLayout,
      template: MyApp.ArticlesPage,
      per_page: 20
    ]
  ]
  ```

  The `:key_path` accepts a list representing the path to the collection in the token.
  For example, `[:data, "articles"]` accesses `token.data["articles"]`.

  For complex scenarios like paginating posts grouped by tag, see the guides.

  ## Collection Sorting

  Collections are sorted before pagination according to the `:sort` option. The default
  is `{:date, {:desc, Date}}` (newest first).

  For collections without dates (like pages), specify a different sort field:

  ```elixir
  collections: [
    pages: [
      permalink: "/pages/:page?",
      sort: :title,  # alphabetical
      # ...
    ]
  ]
  ```
  """

  use Tableau.Extension, key: :paginated_indexes, priority: 700

  @impl Tableau.Extension
  defdelegate config(config), to: TableauPaginationExtension.Config

  @impl Tableau.Extension
  def pre_render(token) do
    collections = token.extensions.paginated_indexes.config.collections

    pages = Enum.flat_map(collections, &generate_collection_pages(&1, token))
    graph = Tableau.Graph.insert(token.graph, pages)

    {:ok, %{token | graph: graph}}
  end

  defp generate_collection_pages({_collection_key, opts}, token) do
    opts.handler.paginate(token, opts)
  end
end

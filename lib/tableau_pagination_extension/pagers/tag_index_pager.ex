defmodule TableauPaginationExtension.TagIndexPager do
  @moduledoc """
  Pager for paginating tag index pages.

  This handler extracts tag structs from `token.tags` and paginates them, supporting
  sorting by entry count (number of posts per tag).

  ## Example

  ```elixir
  collections: [
    tag_index: [
      handler: TagIndexPager,
      key_path: [:tags],
      permalink: "/tags/:page?",
      sort: {:count, :desc},
      per_page: 50
    ]
  ]
  ```
  """

  @behaviour TableauPaginationExtension.Pager

  alias TableauPaginationExtension.Pager

  @impl Pager
  def paginate(token, opts) do
    case get_in(token, opts.key_path) do
      map when is_map(map) ->
        map
        |> extract_tags(opts.sort)
        |> Pager.build_pages(opts.per_page, opts.permalink, opts.layout, opts.template)

      # coveralls-ignore-next-line
      _ ->
        []
    end
  end

  defp extract_tags(tags_map, sort) do
    tags_map
    |> Enum.map(fn {tag, posts} -> Map.put(tag, :count, length(posts)) end)
    |> Pager.sort_collection(sort)
  end
end

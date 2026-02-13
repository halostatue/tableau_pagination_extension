defmodule TableauPaginationExtension.MapIndexPager do
  @moduledoc """
  Pager for paginating map keys as a list.

  This handler extracts the keys from a map and paginates them. Useful for creating an
  index page of all keys in a map collection.

  ## Example

  ```elixir
  collections: [
    tag_index: [
      handler: TableauPaginatedIndex.MapIndexPager,
      key_path: [:tags],
      permalink: "/tags/:page?",
      sort: :entry_count,  # special sort by value list length
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
        |> extract_keys(opts.sort)
        |> Pager.build_pages(opts.per_page, opts.permalink, opts.layout, opts.template)

      # coveralls-ignore-next-line
      _ ->
        []
    end
  end

  defp extract_keys(map, :entry_count) do
    map
    |> Enum.map(fn {key, value} -> {key, length(value)} end)
    |> Enum.sort_by(fn {_key, count} -> count end, :desc)
    |> Enum.map(fn {key, _count} -> key end)
  end

  defp extract_keys(map, {:entry_count, direction}) do
    map
    |> Enum.map(fn {key, value} -> {key, length(value)} end)
    |> Enum.sort_by(fn {_key, count} -> count end, direction)
    |> Enum.map(fn {key, _count} -> key end)
  end

  defp extract_keys(map, sort) do
    map
    |> Map.keys()
    |> Pager.sort_collection(sort)
  end
end

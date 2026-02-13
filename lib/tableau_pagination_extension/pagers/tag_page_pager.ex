defmodule TableauPaginationExtension.TagPagePager do
  @moduledoc """
  Pager for paginating posts within each tag.

  This handler iterates over `token.tags` and generates paginated pages for each tag's
  posts. The tag's slug is used in the permalink.

  ## Example

  ```elixir
  collections: [
    tag_pages: [
      handler: TagPagePager,
      key_path: [:tags],
      permalink: "/tags/:tag/:page?",
      per_page: 20
    ]
  ]
  ```

  The `:tag` placeholder in the permalink will be replaced with the tag's slug.
  """

  @behaviour TableauPaginationExtension.Pager

  alias TableauPaginationExtension.Pager

  @impl Pager
  def validate_permalink(%{first: first, rest: rest}) do
    if (is_nil(first) or String.contains?(first, ":tag")) and String.contains?(rest, ":tag") do
      :ok
    else
      {:error, "TagPagePager requires :tag placeholder in permalink"}
    end
  end

  @impl Pager
  def paginate(token, opts) do
    case get_in(token, opts.key_path) do
      map when is_map(map) -> Enum.flat_map(map, &build_tag_pages(&1, opts))
      # coveralls-ignore-next-line
      _ -> []
    end
  end

  defp build_tag_pages({tag, items}, opts) do
    items
    |> Pager.sort_collection(opts.sort)
    |> Pager.build_pages(opts.per_page, build_tag_permalink(opts.permalink, tag), opts.layout, opts.template)
  end

  defp build_tag_permalink(permalink, %{slug: slug}) do
    %{
      first: replace_tag_placeholder(permalink.first, slug),
      rest: replace_tag_placeholder(permalink.rest, slug)
    }
  end

  defp replace_tag_placeholder(nil, _slug), do: nil
  defp replace_tag_placeholder(pattern, slug), do: String.replace(pattern, ":tag", slug)
end

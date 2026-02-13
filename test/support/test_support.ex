defmodule TableauPaginationExtension.TestSupport do
  @moduledoc false

  def body_length(post), do: String.length(post.body)
  def compare_titles(p1, p2), do: p1.title > p2.title

  defmodule TestTemplate do
    @moduledoc false
    def template(_assigns), do: "<div>test</div>"
  end

  defmodule TestLayout do
    @moduledoc false
    def template(_assigns), do: "<html></html>"
  end
end

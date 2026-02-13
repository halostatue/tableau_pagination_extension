defmodule TableauPaginationExtensionTest do
  use TableauPaginationExtension.TestCase, async: true

  alias TableauPaginationExtension.MapIndexPager
  alias TableauPaginationExtension.MapPagePager
  alias TableauPaginationExtension.TagIndexPager
  alias TableauPaginationExtension.TagPagePager
  alias TableauPaginationExtension.TestSupport
  alias TableauPaginationExtension.TestSupport.TestLayout
  alias TableauPaginationExtension.TestSupport.TestTemplate

  describe "config/1" do
    test "accepts keyword list config" do
      config = [
        enabled: true,
        collections: [
          posts: [
            permalink: "/posts/:page?",
            layout: TestLayout,
            template: TestTemplate,
            per_page: 5
          ]
        ]
      ]

      assert {:ok, result} = TableauPaginationExtension.config(config)
      assert result.enabled == true
      assert is_map(result.collections)
      assert Map.has_key?(result.collections, :posts)
    end

    test "accepts map config" do
      config = %{
        enabled: true,
        collections: %{
          posts: %{
            permalink: "/posts/:page?",
            layout: TestLayout,
            template: TestTemplate,
            per_page: 5
          }
        }
      }

      assert {:ok, result} = TableauPaginationExtension.config(config)
      assert result.enabled == true
    end

    test "requires collections key" do
      config = %{enabled: true}
      assert {:error, ":collections is required"} = TableauPaginationExtension.config(config)
    end

    test "requires permalink in collection config" do
      config = %{
        collections: %{
          posts: %{
            layout: TestLayout,
            template: TestTemplate
          }
        }
      }

      assert {:error, "permalink required"} = TableauPaginationExtension.config(config)
    end

    test "defaults per_page to 10" do
      config = %{
        collections: %{
          posts: %{
            permalink: "/posts/:page?",
            layout: TestLayout,
            template: TestTemplate
          }
        }
      }

      assert {:ok, result} = TableauPaginationExtension.config(config)
      assert result.collections.posts.per_page == 10
    end

    test "accepts custom per_page" do
      config = %{
        collections: %{
          posts: %{
            permalink: "/posts/:page?",
            layout: TestLayout,
            template: TestTemplate,
            per_page: 25
          }
        }
      }

      assert {:ok, result} = TableauPaginationExtension.config(config)
      assert result.collections.posts.per_page == 25
    end

    test "rejects TagPagePager without :tag in permalink" do
      config = %{
        collections: %{
          tag_pages: [
            handler: TagPagePager,
            permalink: "/posts/:page?",
            layout: TestLayout,
            template: TestTemplate
          ]
        }
      }

      assert {:error, "TagPagePager requires :tag placeholder in permalink"} =
               TableauPaginationExtension.config(config)
    end

    test "rejects MapPagePager without :key in permalink" do
      config = %{
        collections: %{
          map_pages: [
            handler: MapPagePager,
            permalink: "/posts/:page?",
            layout: TestLayout,
            template: TestTemplate
          ]
        }
      }

      assert {:error, "MapPagePager requires :key placeholder in permalink"} =
               TableauPaginationExtension.config(config)
    end

    test "rejects permalink without :page" do
      config = %{
        collections: %{
          posts: [
            permalink: "/posts",
            layout: TestLayout,
            template: TestTemplate
          ]
        }
      }

      assert {:error, "permalink must contain :page or :page? placeholder"} =
               TableauPaginationExtension.config(config)
    end

    test "rejects invalid handler module" do
      config = %{
        collections: %{
          posts: [
            handler: NonExistentModule,
            permalink: "/posts/:page?",
            layout: TestLayout,
            template: TestTemplate
          ]
        }
      }

      assert {:error, "handler NonExistentModule could not be loaded"} =
               TableauPaginationExtension.config(config)
    end

    test "rejects :page? not at end of permalink" do
      config = %{
        collections: %{
          posts: [
            permalink: "/posts/:page?/extra",
            layout: TestLayout,
            template: TestTemplate
          ]
        }
      }

      assert {:error, "permalink with :page? placeholder must be at the end"} =
               TableauPaginationExtension.config(config)
    end

    test "accepts explicit first/rest with :page in first at end" do
      config = %{
        collections: %{
          posts: [
            permalink: [first: "/posts/1/:page", rest: "/posts/:page"],
            layout: TestLayout,
            template: TestTemplate
          ]
        }
      }

      assert {:ok, result} = TableauPaginationExtension.config(config)
      assert result.collections.posts.permalink.first == "/posts/1/:page"
    end

    test "rejects explicit first with :page not at end" do
      config = %{
        collections: %{
          posts: [
            permalink: [first: "/posts/:page/extra", rest: "/posts/:page"],
            layout: TestLayout,
            template: TestTemplate
          ]
        }
      }

      assert {:error, "permalink :first must contain :page placeholder at the end"} =
               TableauPaginationExtension.config(config)
    end
  end

  describe "permalink parsing" do
    test "parses optional page suffix pattern" do
      config =
        build_config(
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate
            ]
          ]
        )

      permalink = config.collections.posts.permalink
      assert permalink.first == "/posts"
      assert permalink.rest == "/posts/:page"
    end

    test "parses required page placeholder pattern" do
      config =
        build_config(
          collections: [
            posts: [
              permalink: "/posts/page/:page",
              layout: TestLayout,
              template: TestTemplate
            ]
          ]
        )

      permalink = config.collections.posts.permalink
      assert permalink.first == nil
      assert permalink.rest == "/posts/page/:page"
    end

    test "accepts explicit first/rest keyword list" do
      config =
        build_config(
          collections: [
            posts: [
              permalink: [first: "/blog", rest: "/blog/page/:page"],
              layout: TestLayout,
              template: TestTemplate
            ]
          ]
        )

      permalink = config.collections.posts.permalink
      assert permalink.first == "/blog"
      assert permalink.rest == "/blog/page/:page"
    end
  end

  describe "pre_render/1" do
    test "handles empty collection" do
      pages =
        paginate_collection([],
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10
            ]
          ]
        )

      assert pages == []
    end

    test "generates pages for posts collection" do
      posts = [
        build_post(title: "Post 1", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Post 2", date: ~U[2024-01-02 00:00:00Z]),
        build_post(title: "Post 3", date: ~U[2024-01-01 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10
            ]
          ]
        )

      assert length(pages) == 1
      page = hd(pages)
      assert page.permalink == "/posts"
      assert page.opts.page_number == 1
      assert page.opts.total_pages == 1
      assert page.opts.prev_page == nil
      assert page.opts.next_page == nil
      assert length(page.opts.posts) == 3
    end

    test "generates multiple pages when items exceed per_page" do
      posts =
        for i <- 1..15 do
          build_post(title: "Post #{i}", date: ~U[2024-01-01 00:00:00Z])
        end

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 5
            ]
          ]
        )

      assert length(pages) == 3

      [page1, page2, page3] = pages

      # Page 1
      assert page1.permalink == "/posts"
      assert page1.opts.page_number == 1
      assert page1.opts.total_pages == 3
      assert page1.opts.prev_page == nil
      assert page1.opts.next_page == 2
      assert length(page1.opts.posts) == 5

      # Page 2
      assert page2.permalink == "/posts/2"
      assert page2.opts.page_number == 2
      assert page2.opts.total_pages == 3
      assert page2.opts.prev_page == 1
      assert page2.opts.next_page == 3
      assert length(page2.opts.posts) == 5

      # Page 3
      assert page3.permalink == "/posts/3"
      assert page3.opts.page_number == 3
      assert page3.opts.total_pages == 3
      assert page3.opts.prev_page == 2
      assert page3.opts.next_page == nil
      assert length(page3.opts.posts) == 5
    end

    test "sorts posts by date descending" do
      posts = [
        build_post(title: "Old", date: ~U[2024-01-01 00:00:00Z]),
        build_post(title: "New", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Middle", date: ~U[2024-01-02 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10
            ]
          ]
        )

      page = hd(pages)
      titles = Enum.map(page.opts.posts, & &1.title)
      assert titles == ["New", "Middle", "Old"]
    end

    test "generates correct URLs for pagination links" do
      posts =
        for i <- 1..10 do
          build_post(title: "Post #{i}", date: ~U[2024-01-01 00:00:00Z])
        end

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 3
            ]
          ]
        )

      [page1, page2, _page3, page4] = pages

      # Page 1 URLs
      assert page1.opts.first_page_url == "/posts"
      assert page1.opts.prev_page_url == nil
      assert page1.opts.next_page_url == "/posts/2"
      assert page1.opts.last_page_url == "/posts/4"

      # Page 2 URLs
      assert page2.opts.first_page_url == "/posts"
      assert page2.opts.prev_page_url == "/posts"
      assert page2.opts.next_page_url == "/posts/3"
      assert page2.opts.last_page_url == "/posts/4"

      # Page 4 URLs
      assert page4.opts.first_page_url == "/posts"
      assert page4.opts.prev_page_url == "/posts/3"
      assert page4.opts.next_page_url == nil
      assert page4.opts.last_page_url == "/posts/4"
    end

    test "handles explicit first/rest permalink pattern" do
      posts =
        for i <- 1..8 do
          build_post(title: "Post #{i}", date: ~U[2024-01-01 00:00:00Z])
        end

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: [first: "/blog", rest: "/blog/page/:page"],
              layout: TestLayout,
              template: TestTemplate,
              per_page: 5
            ]
          ]
        )

      [page1, page2] = pages

      assert page1.permalink == "/blog"
      assert page1.opts.first_page_url == "/blog"
      assert page1.opts.next_page_url == "/blog/page/2"

      assert page2.permalink == "/blog/page/2"
      assert page2.opts.prev_page_url == "/blog"
    end
  end

  describe "sorting" do
    test "defaults to date descending with Date comparator" do
      posts = [
        build_post(title: "Old", date: ~U[2024-01-01 00:00:00Z]),
        build_post(title: "New", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Middle", date: ~U[2024-01-02 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["New", "Middle", "Old"]
    end

    test "sorts by field atom with default ascending" do
      posts = [
        build_post(title: "Zebra"),
        build_post(title: "Apple"),
        build_post(title: "Mango")
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: :title
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Apple", "Mango", "Zebra"]
    end

    test "sorts by date atom with default descending" do
      posts = [
        build_post(title: "Old", date: ~U[2024-01-01 00:00:00Z]),
        build_post(title: "New", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Middle", date: ~U[2024-01-02 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: :date
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["New", "Middle", "Old"]
    end

    test "sorts by date ascending explicitly" do
      posts = [
        build_post(title: "Old", date: ~U[2024-01-01 00:00:00Z]),
        build_post(title: "New", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Middle", date: ~U[2024-01-02 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: {:date, :asc}
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Old", "Middle", "New"]
    end

    test "sorts by date descending explicitly" do
      posts = [
        build_post(title: "Old", date: ~U[2024-01-01 00:00:00Z]),
        build_post(title: "New", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Middle", date: ~U[2024-01-02 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: {:date, :desc}
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["New", "Middle", "Old"]
    end

    test "sorts by field with explicit direction" do
      posts = [
        build_post(title: "Zebra"),
        build_post(title: "Apple"),
        build_post(title: "Mango")
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: {:title, :desc}
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Zebra", "Mango", "Apple"]
    end

    test "sorts by field with custom comparator module" do
      posts = [
        build_post(title: "Old", date: ~U[2024-01-01 00:00:00Z]),
        build_post(title: "New", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Middle", date: ~U[2024-01-02 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: {:date, {:asc, DateTime}}
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Old", "Middle", "New"]
    end

    test "sorts with custom extractor function" do
      posts = [
        build_post(title: "Short", body: "Hi"),
        build_post(title: "Long", body: "This is a longer body"),
        build_post(title: "Medium", body: "Medium length")
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: {&String.length(&1.body), :desc}
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Long", "Medium", "Short"]
    end

    test "sorts with MFA extractor" do
      posts = [
        build_post(title: "Short", body: "Hi"),
        build_post(title: "Long", body: "This is a longer body"),
        build_post(title: "Medium", body: "Medium length")
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: {{TestSupport, :body_length, []}, :desc}
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Long", "Medium", "Short"]
    end

    test "sorts with custom comparator function" do
      posts = [
        build_post(title: "Zebra"),
        build_post(title: "Apple"),
        build_post(title: "Mango")
      ]

      comparator = fn p1, p2 -> p1.title > p2.title end

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: comparator
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Zebra", "Mango", "Apple"]
    end

    test "sorts with MFA comparator" do
      posts = [
        build_post(title: "Zebra"),
        build_post(title: "Apple"),
        build_post(title: "Mango")
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: {TestSupport, :compare_titles, []}
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Zebra", "Mango", "Apple"]
    end

    test "preserves order when sort is false" do
      posts = [
        build_post(title: "Third", date: ~U[2024-01-01 00:00:00Z]),
        build_post(title: "First", date: ~U[2024-01-03 00:00:00Z]),
        build_post(title: "Second", date: ~U[2024-01-02 00:00:00Z])
      ]

      pages =
        paginate_collection(posts,
          collections: [
            posts: [
              permalink: "/posts/:page?",
              layout: TestLayout,
              template: TestTemplate,
              per_page: 10,
              sort: false
            ]
          ]
        )

      titles = Enum.map(hd(pages).opts.posts, & &1.title)
      assert titles == ["Third", "First", "Second"]
    end
  end

  describe "data collections" do
    test "paginates data collection with key_path" do
      articles = [
        %{title: "Article 1", author: "Alice"},
        %{title: "Article 2", author: "Bob"},
        %{title: "Article 3", author: "Charlie"}
      ]

      token = %{
        data: %{"articles" => articles},
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  articles: [
                    key_path: [:data, "articles"],
                    permalink: "/articles/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: :title
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      assert length(pages) == 1
      page = hd(pages)
      assert page.permalink == "/articles"
      titles = Enum.map(page.opts.posts, & &1.title)
      assert titles == ["Article 1", "Article 2", "Article 3"]
    end

    test "paginates nested data collection" do
      token = %{
        data: %{
          "content" => %{
            "blog" => [
              %{title: "Post 1"},
              %{title: "Post 2"}
            ]
          }
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  blog: [
                    key_path: [:data, "content", "blog"],
                    permalink: "/blog/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: false
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      assert length(pages) == 1
      page = hd(pages)
      titles = Enum.map(page.opts.posts, & &1.title)
      assert titles == ["Post 1", "Post 2"]
    end

    test "handles missing data collection gracefully" do
      token = %{
        data: %{},
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  missing: [
                    key_path: [:data, "missing"],
                    permalink: "/missing/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      assert Enum.empty?(pages)
    end

    test "sorts data collection by custom field" do
      products = [
        %{name: "Zebra Toy", price: 10},
        %{name: "Apple Toy", price: 5},
        %{name: "Mango Toy", price: 8}
      ]

      token = %{
        data: %{"products" => products},
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  products: [
                    key_path: [:data, "products"],
                    permalink: "/products/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: {:price, :desc}
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      page = hd(pages)
      names = Enum.map(page.opts.posts, & &1.name)
      assert names == ["Zebra Toy", "Mango Toy", "Apple Toy"]
    end
  end

  describe "MapIndexPager" do
    test "paginates map keys" do
      token = %{
        categories: %{
          "tech" => [%{title: "Post 1"}, %{title: "Post 2"}],
          "food" => [%{title: "Post 3"}],
          "travel" => [%{title: "Post 4"}, %{title: "Post 5"}, %{title: "Post 6"}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  category_index: [
                    handler: MapIndexPager,
                    key_path: [:categories],
                    permalink: "/categories/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: false
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      assert length(pages) == 1
      page = hd(pages)
      keys = Enum.map(page.opts.posts, &to_string/1)
      assert length(keys) == 3
      assert "tech" in keys
      assert "food" in keys
      assert "travel" in keys
    end

    test "sorts map keys by entry_count descending" do
      token = %{
        categories: %{
          "tech" => [%{title: "Post 1"}, %{title: "Post 2"}],
          "food" => [%{title: "Post 3"}],
          "travel" => [%{title: "Post 4"}, %{title: "Post 5"}, %{title: "Post 6"}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  category_index: [
                    handler: MapIndexPager,
                    key_path: [:categories],
                    permalink: "/categories/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: :entry_count
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      page = hd(pages)
      keys = Enum.map(page.opts.posts, &to_string/1)
      assert keys == ["travel", "tech", "food"]
    end

    test "sorts map keys by entry_count ascending" do
      token = %{
        categories: %{
          "tech" => [%{title: "Post 1"}, %{title: "Post 2"}],
          "food" => [%{title: "Post 3"}],
          "travel" => [%{title: "Post 4"}, %{title: "Post 5"}, %{title: "Post 6"}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  category_index: [
                    handler: MapIndexPager,
                    key_path: [:categories],
                    permalink: "/categories/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: {:entry_count, :asc}
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      page = hd(pages)
      keys = Enum.map(page.opts.posts, &to_string/1)
      assert keys == ["food", "tech", "travel"]
    end
  end

  describe "MapPagePager" do
    test "paginates each map value separately" do
      token = %{
        categories: %{
          "tech" => [
            %{title: "Tech 1"},
            %{title: "Tech 2"},
            %{title: "Tech 3"}
          ],
          "food" => [
            %{title: "Food 1"},
            %{title: "Food 2"}
          ]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  category_pages: [
                    handler: MapPagePager,
                    key_path: [:categories],
                    permalink: "/categories/:key/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 2,
                    sort: false
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))
        |> Enum.sort_by(& &1.permalink)

      # Should have 3 pages: tech/1, tech/2, food/1
      assert length(pages) == 3

      [food_page, tech_page1, tech_page2] = pages

      assert food_page.permalink == "/categories/food"
      assert length(food_page.opts.posts) == 2

      assert tech_page1.permalink == "/categories/tech"
      assert length(tech_page1.opts.posts) == 2

      assert tech_page2.permalink == "/categories/tech/2"
      assert length(tech_page2.opts.posts) == 1
    end

    test "handles required :page in permalink" do
      token = %{
        categories: %{
          "tech" => [%{title: "Tech 1"}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  category_pages: [
                    handler: MapPagePager,
                    key_path: [:categories],
                    permalink: "/categories/:key/:page",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: false
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      assert length(pages) == 1
      page = hd(pages)
      assert page.permalink == "/categories/tech/1"
    end

    test "replaces :key placeholder in permalinks" do
      token = %{
        categories: %{
          "elixir" => [%{title: "Post 1"}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  category_pages: [
                    handler: MapPagePager,
                    key_path: [:categories],
                    permalink: "/cat/:key/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: false
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      page = hd(pages)
      assert page.permalink == "/cat/elixir"
    end
  end

  describe "TagIndexPager" do
    test "paginates tag index sorted by entry count" do
      elixir_tag = %{title: "Elixir", permalink: "/tags/elixir", tag: "Elixir", slug: "elixir"}
      erlang_tag = %{title: "Erlang", permalink: "/tags/erlang", tag: "Erlang", slug: "erlang"}
      rust_tag = %{title: "Rust", permalink: "/tags/rust", tag: "Rust", slug: "rust"}

      token = %{
        tags: %{
          elixir_tag => [%{title: "Post 1"}, %{title: "Post 2"}],
          erlang_tag => [%{title: "Post 3"}],
          rust_tag => [%{title: "Post 4"}, %{title: "Post 5"}, %{title: "Post 6"}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  tag_index: [
                    handler: TagIndexPager,
                    key_path: [:tags],
                    permalink: "/tags/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: {:count, :desc}
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      page = hd(pages)
      tags = page.opts.posts
      assert length(tags) == 3
      assert Enum.at(tags, 0).slug == "rust"
      assert Enum.at(tags, 1).slug == "elixir"
      assert Enum.at(tags, 2).slug == "erlang"
    end
  end

  describe "TagPagePager" do
    test "handles required :page in permalink" do
      elixir_tag = %{title: "Elixir", permalink: "/tags/elixir", tag: "Elixir", slug: "elixir"}

      token = %{
        tags: %{
          elixir_tag => [%{title: "Elixir 1", date: ~U[2024-01-01 00:00:00Z]}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  tag_pages: [
                    handler: TagPagePager,
                    key_path: [:tags],
                    permalink: "/tags/:tag/:page",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: {:date, {:desc, DateTime}}
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      assert length(pages) == 1
      page = hd(pages)
      assert page.permalink == "/tags/elixir/1"
    end

    test "paginates posts for each tag" do
      elixir_tag = %{title: "Elixir", permalink: "/tags/elixir", tag: "Elixir", slug: "elixir"}
      erlang_tag = %{title: "Erlang", permalink: "/tags/erlang", tag: "Erlang", slug: "erlang"}

      token = %{
        tags: %{
          elixir_tag => [
            %{title: "Elixir 1", date: ~U[2024-01-01 00:00:00Z]},
            %{title: "Elixir 2", date: ~U[2024-01-02 00:00:00Z]},
            %{title: "Elixir 3", date: ~U[2024-01-03 00:00:00Z]}
          ],
          erlang_tag => [
            %{title: "Erlang 1", date: ~U[2024-01-01 00:00:00Z]},
            %{title: "Erlang 2", date: ~U[2024-01-02 00:00:00Z]}
          ]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  tag_pages: [
                    handler: TagPagePager,
                    key_path: [:tags],
                    permalink: "/tags/:tag/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 2,
                    sort: {:date, {:desc, DateTime}}
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))
        |> Enum.sort_by(& &1.permalink)

      # Should have 3 pages: elixir/1, elixir/2, erlang/1
      assert length(pages) == 3

      [elixir_page1, elixir_page2, erlang_page] = pages

      assert elixir_page1.permalink == "/tags/elixir"
      assert length(elixir_page1.opts.posts) == 2
      assert Enum.at(elixir_page1.opts.posts, 0).title == "Elixir 3"

      assert elixir_page2.permalink == "/tags/elixir/2"
      assert length(elixir_page2.opts.posts) == 1

      assert erlang_page.permalink == "/tags/erlang"
      assert length(erlang_page.opts.posts) == 2
    end

    test "replaces :tag placeholder with tag slug" do
      elixir_tag = %{title: "Elixir", permalink: "/tags/elixir", tag: "Elixir", slug: "elixir"}

      token = %{
        tags: %{
          elixir_tag => [%{title: "Post 1", date: ~U[2024-01-01 00:00:00Z]}]
        },
        graph: Graph.new(),
        extensions: %{
          paginated_indexes: %{
            config:
              build_config(
                collections: [
                  tag_pages: [
                    handler: TagPagePager,
                    key_path: [:tags],
                    permalink: "/t/:tag/:page?",
                    layout: TestLayout,
                    template: TestTemplate,
                    per_page: 10,
                    sort: false
                  ]
                ]
              )
          }
        }
      }

      {:ok, result} = TableauPaginationExtension.pre_render(token)

      pages =
        result.graph
        |> Graph.vertices()
        |> Enum.filter(&is_struct(&1, Tableau.Page))

      page = hd(pages)
      assert page.permalink == "/t/elixir"
    end
  end
end

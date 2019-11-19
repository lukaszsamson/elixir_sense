defmodule ElixirSense.SuggestionsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "empty hint" do
    buffer = """
    defmodule MyModule do

    end
    """

    list = ElixirSense.suggestions(buffer, 2, 7)

    assert Enum.find(list, fn s -> match?(%{name: "import", arity: 2}, s) end) == %{
             args: "module,opts",
             arity: 2,
             name: "import",
             origin: "Kernel.SpecialForms",
             spec: "",
             summary: "Imports functions and macros from other modules.",
             type: "macro"
           }

    assert Enum.find(list, fn s -> match?(%{name: "quote", arity: 2}, s) end) == %{
             arity: 2,
             origin: "Kernel.SpecialForms",
             spec: "",
             type: "macro",
             args: "opts,block",
             name: "quote",
             summary: "Gets the representation of any expression."
           }

    assert Enum.find(list, fn s -> match?(%{name: "require", arity: 2}, s) end) == %{
             arity: 2,
             origin: "Kernel.SpecialForms",
             spec: "",
             type: "macro",
             args: "module,opts",
             name: "require",
             summary: "Requires a module in order to use its macros."
           }
  end

  test "without empty hint" do
    buffer = """
    defmodule MyModule do
      is_b
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 7)

    assert list == [
             %{type: :hint, value: "is_b"},
             %{
               args: "term",
               arity: 1,
               name: "is_binary",
               origin: "Kernel",
               spec: "@spec is_binary(term) :: boolean",
               summary: "Returns `true` if `term` is a binary; otherwise returns `false`.",
               type: "function"
             },
             %{
               args: "term",
               arity: 1,
               name: "is_bitstring",
               origin: "Kernel",
               spec: "@spec is_bitstring(term) :: boolean",
               summary:
                 "Returns `true` if `term` is a bitstring (including a binary); otherwise returns `false`.",
               type: "function"
             },
             %{
               args: "term",
               arity: 1,
               name: "is_boolean",
               origin: "Kernel",
               spec: "@spec is_boolean(term) :: boolean",
               summary:
                 "Returns `true` if `term` is either the atom `true` or the atom `false` (i.e.,\na boolean); otherwise returns `false`.",
               type: "function"
             }
           ]
  end

  test "with an alias" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      MyList.flat
    end
    """

    list = ElixirSense.suggestions(buffer, 3, 14)

    assert list == [
             %{type: :hint, value: "MyList.flatten"},
             %{
               args: "list",
               arity: 1,
               name: "flatten",
               origin: "List",
               spec: "@spec flatten(deep_list) :: list when deep_list: [any | deep_list]",
               summary: "Flattens the given `list` of nested lists.",
               type: "function"
             },
             %{
               args: "list,tail",
               arity: 2,
               name: "flatten",
               origin: "List",
               spec:
                 "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var",
               summary:
                 "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
               type: "function"
             }
           ]
  end

  test "with a module hint" do
    buffer = """
    defmodule MyModule do
      Str
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 6)

    assert list == [
             %{type: :hint, value: "Str"},
             %{
               name: "Stream",
               subtype: :struct,
               summary: "Functions for creating and composing streams.",
               type: :module
             },
             %{
               name: "String",
               subtype: nil,
               summary: "A String in Elixir is a UTF-8 encoded binary.",
               type: :module
             },
             %{
               name: "StringIO",
               subtype: nil,
               summary: "Controls an IO device process that wraps a string.",
               type: :module
             }
           ]
  end

  test "lists callbacks" do
    buffer = """
    defmodule MyServer do
      use GenServer

    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 7)
      |> Enum.filter(fn s -> s.type == :callback && s.name == :code_change end)

    assert [
             %{
               args: "old_vsn,state,extra",
               arity: 3,
               name: :code_change,
               origin: "GenServer",
               spec: "@callback code_change(old_vsn, state :: term, extra :: term) ::" <> _,
               summary:
                 "Invoked to change the state of the `GenServer` when a different version of a\nmodule is loaded (hot code swapping) and the state's term structure should be\nchanged.",
               type: :callback
             }
           ] = list
  end

  test "callback suggestions should not crash with unquote(__MODULE__)" do
    buffer = """
    defmodule Dummy do
      @doc false
      defmacro __using__() do
        quote location: :keep do
          @behaviour unquote(__MODULE__)
        end
      end
    end
    """

    assert [%{} | _] = ElixirSense.suggestions(buffer, 8, 5)
  end

  test "lists protocol functions" do
    buffer = """
    defimpl Enumerable, for: MyStruct do

    end
    """

    list =
      ElixirSense.suggestions(buffer, 2, 3)
      |> Enum.filter(fn s -> s[:name] == :reduce end)

    assert [
             %{
               args: "enumerable,acc,fun",
               arity: 3,
               name: :reduce,
               origin: "Enumerable",
               spec: spec,
               summary: "Reduces the `enumerable` into an element.",
               type: :protocol_function
             }
           ] = list

    if Version.match?(System.version, "~>1.9") do
      # prior to 1.9 there were no specs
      assert spec == "@spec reduce(t, acc, reducer) :: result"
    end
  end

  test "lists function return values" do
    buffer = """
    defmodule MyServer do
      use ElixirSenseExample.ExampleBehaviour

      def handle_call(request, from, state) do

      end
    end
    """

    list =
      ElixirSense.suggestions(buffer, 5, 5)
      |> Enum.filter(fn s -> s.type == :return end)

    assert list == [
             %{
               description: "{:reply, reply, new_state}",
               snippet: "{:reply, \"${1:reply}$\", \"${2:new_state}$\"}",
               spec: "{:reply, reply, new_state} when reply: term, new_state: term, reason: term",
               type: :return
             },
             %{
               description:
                 "{:reply, reply, new_state, timeout | :hibernate | {:continue, term}}",
               snippet:
                 "{:reply, \"${1:reply}$\", \"${2:new_state}$\", \"${3:timeout | :hibernate | {:continue, term}}$\"}",
               spec:
                 "{:reply, reply, new_state, timeout | :hibernate | {:continue, term}} when reply: term, new_state: term, reason: term",
               type: :return
             },
             %{
               description: "{:noreply, new_state}",
               snippet: "{:noreply, \"${1:new_state}$\"}",
               spec: "{:noreply, new_state} when reply: term, new_state: term, reason: term",
               type: :return
             },
             %{
               description: "{:noreply, new_state, timeout | :hibernate | {:continue, term}}",
               snippet:
                 "{:noreply, \"${1:new_state}$\", \"${2:timeout | :hibernate | {:continue, term}}$\"}",
               spec:
                 "{:noreply, new_state, timeout | :hibernate | {:continue, term}} when reply: term, new_state: term, reason: term",
               type: :return
             },
             %{
               description: "{:stop, reason, reply, new_state}",
               snippet: "{:stop, \"${1:reason}$\", \"${2:reply}$\", \"${3:new_state}$\"}",
               spec:
                 "{:stop, reason, reply, new_state} when reply: term, new_state: term, reason: term",
               type: :return
             },
             %{
               description: "{:stop, reason, new_state}",
               snippet: "{:stop, \"${1:reason}$\", \"${2:new_state}$\"}",
               spec: "{:stop, reason, new_state} when reply: term, new_state: term, reason: term",
               type: :return
             }
           ]
  end

  test "lists params and vars" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def handle_call(request, _from, state) do
        var1 = true

      end

      def init(arg), do: arg

      def handle_cast(arg, _state) when is_atom(arg) do
        :ok
      end
    end
    """

    list =
      ElixirSense.suggestions(buffer, 6, 5)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :request, type: :variable},
             %{name: :state, type: :variable},
             %{name: :var1, type: :variable}
           ]

    list =
      ElixirSense.suggestions(buffer, 9, 22)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :arg, type: :variable}
           ]

    list =
      ElixirSense.suggestions(buffer, 11, 45)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :arg, type: :variable}
           ]
  end

  test "lists params in fn's" do
    buffer = """
    defmodule MyServer do
      my = fn arg -> arg + 1 end
    end
    """

    list =
      ElixirSense.suggestions(buffer, 2, 19)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :arg, type: :variable}
           ]
  end

  test "lists params in protocol implementations" do
    buffer = """
    defimpl Enum, for: [MyStruct, MyOtherStruct] do
      def count(term), do:
    end
    """

    list =
      ElixirSense.suggestions(buffer, 2, 24)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :term, type: :variable}
           ]
  end

  test "lists vars in []" do
    buffer = """
    defmodule MyServer do
      my = %{}
      x = 4
      my[]

    end
    """

    list =
      ElixirSense.suggestions(buffer, 4, 6)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :my, type: :variable},
             %{name: :x, type: :variable}
           ]
  end

  test "lists vars in unfinished []" do
    buffer = """
    defmodule MyServer do
      my = %{}
      x = 4
      my[

    end
    """

    list =
      ElixirSense.suggestions(buffer, 4, 6)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :my, type: :variable},
             %{name: :x, type: :variable}
           ]
  end

  test "lists vars in string interpolation" do
    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{}"

    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :x, type: :variable}
           ]
  end

  test "lists vars in unfinished string interpolation" do
    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{

    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :x, type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{"

    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :x, type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{}

    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :x, type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{x[

    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :x, type: :variable}
           ]
  end

  test "lists vars in heredoc interpolation" do
    # TODO fix on < 1.9
    if Version.match?(System.version, "~>1.9") do
    buffer = """
    defmodule MyServer do
      x = 4
      \"\"\"
      abc\#{}
      \"\"\"

    end
    """

    list =
      ElixirSense.suggestions(buffer, 4, 8)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :x, type: :variable}
           ]
    end
  end

  test "lists vars in unfinished heredoc interpolation" do
    # The cases below are not supported as elixir parser returns unexpected error
    # {:error, {5, "unexpected token: ", <<34, 0, 34, 32, 40, 99, 111, 108, 117, 109, 110, 32, 49, 44, 32, 99, 111, 100, 101, 32, 112, 111, 105, 110, 116, 32, 85, 43, 48, 48, 48, 48, 41>>}}
    # see https://github.com/elixir-lang/elixir/issues/9252

    # buffer = """
    # defmodule MyServer do
    #   x = 4
    #   \"\"\"
    #   abc\#{
    #   \"\"\"

    # end
    # """

    # list =
    #   ElixirSense.suggestions(buffer, 4, 8)
    #   |> Enum.filter(fn s -> s.type == :variable end)

    # assert list == [
    #   %{name: :x, type: :variable},
    # ]

    # buffer = """
    # defmodule MyServer do
    #   x = 4
    #   \"\"\"
    #   abc\#{

    # end
    # """

    # list =
    #   ElixirSense.suggestions(buffer, 4, 8)
    #   |> Enum.filter(fn s -> s.type == :variable end)

    # assert list == [
    #   %{name: :x, type: :variable},
    # ]

    # TODO fix on < 1.9
    if Version.match?(System.version, "~>1.9") do
      buffer = """
      defmodule MyServer do
        x = 4
        \"\"\"
        abc\#{}

      end
      """

      list =
        ElixirSense.suggestions(buffer, 4, 8)
        |> Enum.filter(fn s -> s.type == :variable end)

      assert list == [
              %{name: :x, type: :variable}
            ]
    end
  end

  test "lists params in fn's not finished multiline" do
    buffer = """
    defmodule MyServer do
      my = fn arg ->

    end
    """

    assert capture_io(:stderr, fn ->
             list =
               ElixirSense.suggestions(buffer, 3, 5)
               |> Enum.filter(fn s -> s.type == :variable end)

             send(self(), {:result, list})
           end) =~ "an expression is always required on the right side of ->"

    assert_received {:result, list}

    assert list == [
             %{name: :arg, type: :variable},
             %{name: :my, type: :variable}
           ]
  end

  test "lists params in fn's not finished" do
    buffer = """
    defmodule MyServer do
      my = fn arg ->
    end
    """

    assert capture_io(:stderr, fn ->
             list =
               ElixirSense.suggestions(buffer, 2, 19)
               |> Enum.filter(fn s -> s.type == :variable end)

             send(self(), {:result, list})
           end) =~ "an expression is always required on the right side of ->"

    assert_received {:result, list}

    assert list == [
             %{name: :arg, type: :variable},
             # TODO my is not defined
             %{name: :my, type: :variable}
           ]
  end

  test "lists params in defs not finished" do
    buffer = """
    defmodule MyServer do
      def my(arg), do:
    end
    """

    list =
      ElixirSense.suggestions(buffer, 2, 20)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :arg, type: :variable}
           ]
  end

  test "lists params and vars in case clauses" do
    buffer = """
    defmodule MyServer do
      def fun(request) do
        case request do
          {:atom1, vara} ->
            :ok
          {:atom2, varb} -> :ok
        end

      end
    end
    """

    list =
      ElixirSense.suggestions(buffer, 5, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :request, type: :variable},
             %{name: :vara, type: :variable}
           ]

    list =
      ElixirSense.suggestions(buffer, 6, 25)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :request, type: :variable},
             %{name: :varb, type: :variable}
           ]

    list =
      ElixirSense.suggestions(buffer, 8, 4)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :request, type: :variable}
           ]
  end

  test "lists params and vars in cond clauses" do
    buffer = """
    defmodule MyServer do
      def fun(request) do
        cond do
          vara = Enum.find(request, 4) ->
            :ok
          varb = Enum.find(request, 5) -> :ok
          true -> :error
        end

      end
    end
    """

    list =
      ElixirSense.suggestions(buffer, 5, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :request, type: :variable},
             %{name: :vara, type: :variable}
           ]

    list =
      ElixirSense.suggestions(buffer, 6, 39)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :request, type: :variable},
             %{name: :varb, type: :variable}
           ]

    list =
      ElixirSense.suggestions(buffer, 9, 4)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: :request, type: :variable}
           ]
  end

  test "lists attributes" do
    buffer = """
    defmodule MyModule do
      @my_attribute1 true
      @my_attribute2 false
      @
    end
    """

    list =
      ElixirSense.suggestions(buffer, 4, 4)
      |> Enum.filter(fn s -> s.type == :attribute end)

    assert list == [
             %{name: "@my_attribute1", type: :attribute},
             %{name: "@my_attribute2", type: :attribute}
           ]
  end

  test "functions defined in the module" do
    buffer = """
    defmodule ElixirSenseExample.ModuleA do
      def test_fun_pub(a), do: :ok

      def some_fun() do
        te
        a = &test_fun_pr
        is_bo
        del
        my_
      end

      defp test_fun_priv(), do: :ok
      defp is_boo_overlaps_kernel(), do: :ok
      defdelegate delegate_defined, to: Kernel, as: :is_binary
      defdelegate delegate_not_defined, to: Dummy, as: :hello
      defguard my_guard_pub(value) when is_integer(value) and rem(value, 2) == 0
      defguardp my_guard_priv(value) when is_integer(value)
      defmacro some_macro(a) do
        quote do: :ok
      end
    end
    """

    assert [
             %{type: :hint, value: "test_fun_p"},
             %{
               arity: 0,
               name: "test_fun_priv",
               origin: "ElixirSenseExample.ModuleA",
               type: "function"
             },
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleA",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 5, 7)

    assert [
             %{type: :hint, value: "test_fun_priv"},
             %{
               arity: 0,
               name: "test_fun_priv",
               origin: "ElixirSenseExample.ModuleA",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 6, 21)

    assert [
             %{type: :hint, value: "is_boo"},
             %{
               arity: 1,
               name: "is_boolean",
               origin: "Kernel",
               type: "function"
             },
             %{
               arity: 0,
               name: "is_boo_overlaps_kernel",
               origin: "ElixirSenseExample.ModuleA",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 7, 10)

    assert [
             %{type: :hint, value: "delegate_"},
             %{
               arity: 0,
               name: "delegate_defined",
               origin: "ElixirSenseExample.ModuleA",
               type: "function"
             },
             %{
               arity: 0,
               name: "delegate_not_defined",
               origin: "ElixirSenseExample.ModuleA",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 8, 8)

    assert [
             %{type: :hint, value: "my_guard_p"},
             %{
               arity: 1,
               name: "my_guard_pub",
               origin: "ElixirSenseExample.ModuleA",
               type: "macro"
             },
             %{
               arity: 1,
               name: "my_guard_priv",
               origin: "ElixirSenseExample.ModuleA",
               type: "macro"
             }
           ] = ElixirSense.suggestions(buffer, 9, 8)
  end

  test "functions defined in other module fully qualified" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample.ModuleA do
      def some_fun() do
        ElixirSenseExample.ModuleO.te
      end
    end
    """

    assert [
             %{type: :hint, value: "ElixirSenseExample.ModuleO.test_fun_pub"},
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleO",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 8, 34)
  end

  test "functions defined in other module aliased" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample.ModuleA do
      alias ElixirSenseExample.ModuleO
      def some_fun() do
        ModuleO.te
      end
    end
    """

    assert [
             %{type: :hint, value: "ModuleO.test_fun_pub"},
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleO",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 9, 15)
  end

  test "functions defined in other module imported" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample.ModuleA do
      import ElixirSenseExample.ModuleO
      def some_fun() do
        te
      end
    end
    """

    assert [
             %{type: :hint, value: "test_fun_pub"},
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleO",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 9, 7)
  end

  test "functions and module suggestions with __MODULE__" do
    buffer = """
    defmodule ElixirSenseExample.SmodO do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample do
      def test_fun_priv1(a), do: :ok
      def some_fun() do
        __MODULE__.Sm
        __MODULE__.SmodO.te
        __MODULE__.te
      end
    end
    """

    assert [
             %{type: :hint, value: "__MODULE__.SmodO"},
             %{
               name: "SmodO",
               type: :module
             }
           ] = ElixirSense.suggestions(buffer, 9, 18)

    assert [
             %{type: :hint, value: "__MODULE__.SmodO.test_fun_pub"},
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.SmodO",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 10, 24)

    assert [
             %{type: :hint, value: "__MODULE__.test_fun_priv1"},
             %{
               arity: 1,
               name: "test_fun_priv1",
               origin: "ElixirSenseExample",
               type: "function"
             }
           ] = ElixirSense.suggestions(buffer, 11, 18)
  end

  test "Elixir module" do
    buffer = """
    defmodule MyModule do
      El
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 5)

    assert Enum.at(list, 0) == %{type: :hint, value: "Elixir"}
    assert Enum.at(list, 1) == %{type: :module, name: "Elixir", subtype: nil, summary: ""}
  end

  test "suggestion for aliases modules defined by require clause" do
    buffer = """
    defmodule Mod do
      require Integer, as: I
      I.is_o
    end
    """

    list = ElixirSense.suggestions(buffer, 3, 9)
    assert Enum.at(list, 1).name == "is_odd"
  end

  test "suggestion for struct fields" do
    buffer = """
    defmodule Mod do
      %IO.Stream{
    end
    """

    list =
      ElixirSense.suggestions(buffer, 2, 14)
      |> Enum.filter(&(&1.type in [:field, :hint]))

    assert list == [
             %{type: :hint, value: ""},
             %{name: :device, origin: "IO.Stream", type: :field},
             %{name: :line_or_bytes, origin: "IO.Stream", type: :field},
             %{name: :raw, origin: "IO.Stream", type: :field}
           ]
  end

  test "suggestion for aliased struct fields" do
    buffer = """
    defmodule Mod do
      alias IO.Stream
      %Stream{
    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 11)
      |> Enum.filter(&(&1.type in [:field, :hint]))

    assert list == [
             %{type: :hint, value: ""},
             %{name: :device, origin: "IO.Stream", type: :field},
             %{name: :line_or_bytes, origin: "IO.Stream", type: :field},
             %{name: :raw, origin: "IO.Stream", type: :field}
           ]
  end

  test "suggestion for aliased struct fields atom module" do
    buffer = """
    defmodule Mod do
      alias IO.Stream
      %:"Elixir.Stream"{
    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 21)
      |> Enum.filter(&(&1.type in [:field, :hint]))

    assert list == [
             %{type: :hint, value: ""},
             %{name: :device, origin: "IO.Stream", type: :field},
             %{name: :line_or_bytes, origin: "IO.Stream", type: :field},
             %{name: :raw, origin: "IO.Stream", type: :field}
           ]
  end

  test "suggestion for metadata struct fields" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %MyServer{}
        %MyServer{field_2: "2", }
      end
    end
    """

    list =
      ElixirSense.suggestions(buffer, 8, 15)
      |> Enum.filter(&(&1.type in [:field, :hint]))

    assert list == [
             %{type: :hint, value: ""},
             %{name: :field_1, origin: "MyServer", type: :field},
             %{name: :field_2, origin: "MyServer", type: :field}
           ]

    list = ElixirSense.suggestions(buffer, 9, 28)

    assert list == [
             %{type: :hint, value: ""},
             %{name: :field_1, origin: "MyServer", type: :field}
           ]
  end

  test "suggestion for metadata struct fields atom module" do
    buffer = """
    defmodule :my_server do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %:my_server{}
        %:my_server{field_2: "2", }
      end
    end
    """

    list =
      ElixirSense.suggestions(buffer, 8, 17)
      |> Enum.filter(&(&1.type in [:field, :hint]))

    assert list == [
             %{type: :hint, value: ""},
             %{name: :field_1, origin: ":my_server", type: :field},
             %{name: :field_2, origin: ":my_server", type: :field}
           ]

    list = ElixirSense.suggestions(buffer, 9, 30)

    assert list == [
             %{type: :hint, value: ""},
             %{name: :field_1, origin: ":my_server", type: :field}
           ]
  end

  test "suggestion for metadata struct fields multiline" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %MyServer{
          field_2: "2",

        }
      end
    end
    """

    list = ElixirSense.suggestions(buffer, 10, 7)

    assert list == [
             %{type: :hint, value: ""},
             %{name: :field_1, origin: "MyServer", type: :field}
           ]
  end

  test "suggestion for metadata struct fields when using `__MODULE__`" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %__MODULE__{field_2: "2", }
      end
    end
    """

    list = ElixirSense.suggestions(buffer, 8, 31)

    assert list == [
             %{type: :hint, value: ""},
             %{name: :field_1, origin: "MyServer", type: :field}
           ]
  end

  test "suggestion for vars in struct update" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        some_field: ""
      ]

      def func(%MyServer{} = some_arg) do
        %MyServer{so
      end
    end
    """

    list = ElixirSense.suggestions(buffer, 8, 17)

    assert list == [
             %{type: :hint, value: "so"},
             %{origin: "MyServer", type: :field, name: :some_field},
             %{name: :some_arg, type: :variable}
           ]
  end

  test "suggestion for funcs and vars in struct" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        some_field: ""
      ]

      def other_func(), do: :ok

      def func(%MyServer{} = some_arg, other_arg) do
        %MyServer{some_arg |
          field_1: ot
      end
    end
    """

    list = ElixirSense.suggestions(buffer, 11, 18)

    assert list == [
             %{type: :hint, value: "other_func"},
             %{name: :other_arg, type: :variable},
             %{
               name: "other_func",
               type: "function",
               args: "",
               arity: 0,
               origin: "MyServer",
               spec: nil,
               summary: ""
             }
           ]
  end

  test "no suggestion of fields when the module is not a struct" do
    buffer = """
    defmodule Mod do
      %Enum{
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 9)
    assert Enum.any?(list, fn %{type: type} -> type == :field end) == false
  end

  test "suggest modules to alias" do
    buffer = """
    defmodule MyModule do
      alias Str
    end
    """

    list =
      ElixirSense.suggestions(buffer, 2, 12)
      |> Enum.filter(fn s -> s.type == :module end)

    assert [
             %{name: "Stream"},
             %{name: "String"},
             %{name: "StringIO"}
           ] = list
  end

  test "suggest modules to alias with __MODULE__" do
    buffer = """
    defmodule Stream do
      alias __MODULE__.Re
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 22)

    assert [%{type: :hint, value: "__MODULE__.Reducers"}, %{name: "Reducers", type: :module} | _] =
             list
  end

  test "suggest modules to alias v1.2 syntax" do
    buffer = """
    defmodule MyModule do
      alias Stream.{Re
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 19)

    assert [%{type: :hint, value: "Reducers"}, %{name: "Reducers", type: :module}] = list
  end

  test "suggest modules to alias v1.2 syntax with __MODULE__" do
    buffer = """
    defmodule Stream do
      alias __MODULE__.{Re
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 23)

    assert [%{type: :hint, value: "Reducers"}, %{name: "Reducers", type: :module}] = list
  end

  describe "suggestion for param options" do
    test "suggest more than one option" do
      buffer = "Local.func_with_options("

      list = suggestions_by_type(:param_option, buffer)
      assert length(list) > 1
    end

    test "suggest the same list when options are already set" do
      buffer1 = "Local.func_with_options("
      buffer2 = "Local.func_with_options(local_o: :an_atom, "

      assert capture_io(:stderr, fn ->
               result1 = suggestions_by_type(:param_option, buffer1)
               result2 = suggestions_by_type(:param_option, buffer2)
               send(self(), {:results, result1, result2})
             end) =~ "trailing commas are not allowed inside function/macro"

      assert_received {:results, result1, result2}
      assert result1 == result2
    end

    test "options as inline list" do
      buffer = "Local.func_with_options_as_inline_list("

      assert %{type_spec: "local_t()", expanded_spec: "@type local_t() :: atom()"} =
               suggestion_by_name(:local_o, buffer)

      assert %{
               type_spec: "keyword()",
               expanded_spec: """
               @type keyword() :: [
                 {atom(), any()}
               ]\
               """
             } = suggestion_by_name(:builtin_o, buffer)
    end

    test "options vars defined in when" do
      type_spec = "local_t()"
      origin = "ElixirSenseExample.ModuleWithTypespecs.Local"
      spec = "@type local_t() :: atom()"

      buffer = "Local.func_with_option_var_defined_in_when("
      suggestion = suggestion_by_name(:local_o, buffer)

      assert suggestion.type_spec == type_spec
      assert suggestion.origin == origin
      assert suggestion.expanded_spec == spec

      buffer = "Local.func_with_options_var_defined_in_when("
      suggestion = suggestion_by_name(:local_o, buffer)

      assert suggestion.type_spec == type_spec
      assert suggestion.origin == origin
      assert suggestion.expanded_spec == spec
    end

    test "opaque type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:opaque_o, buffer)

      assert suggestion.type_spec == "opaque_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@opaque opaque_t() :: atom()"
      assert suggestion.doc == "Local opaque type"
    end

    test "private type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:private_o, buffer)

      assert suggestion.type_spec == "private_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@typep private_t() :: atom()"
      assert suggestion.doc == ""
    end

    test "local type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:local_o, buffer)

      assert suggestion.type_spec == "local_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@type local_t() :: atom()"
      assert suggestion.doc == "Local type"
    end

    test "local type with params" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:local_with_params_o, buffer)

      assert suggestion.type_spec == "local_t(atom(), integer())"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@type local_t(a, b) :: {a, b}"
    end

    test "basic type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:basic_o, buffer)

      assert suggestion.type_spec == "pid()"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == "A process identifier, pid, identifies a process"
    end

    test "basic type with params" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:basic_with_params_o, buffer)

      assert suggestion.type_spec == "[atom(), ...]"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == "Non-empty proper list"
    end

    test "built-in type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:builtin_o, buffer)

      assert suggestion.type_spec == "keyword()"
      assert suggestion.origin == ""

      assert suggestion.expanded_spec == """
             @type keyword() :: [
               {atom(), any()}
             ]\
             """

      assert suggestion.doc == "A keyword list"
    end

    test "built-in type with params" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:builtin_with_params_o, buffer)

      assert suggestion.type_spec == "keyword(term())"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec == "@type keyword(t) :: [{atom(), t}]"
      assert suggestion.doc == "A keyword list with values of type `t`"
    end

    test "union type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:union_o, buffer)

      assert suggestion.type_spec == "union_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"

      assert suggestion.expanded_spec == """
             @type union_t() ::
               atom() | integer()\
             """
    end

    test "list type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:list_o, buffer)

      assert suggestion.type_spec == "list_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@type list_t() :: [:trace | :log]"
    end

    test "remote type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:remote_o, buffer)

      assert suggestion.type_spec == "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec == "@type remote_t() :: atom()"
      assert suggestion.doc == "Remote type"
    end

    test "remote type with args" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:remote_with_params_o, buffer)

      assert suggestion.type_spec ==
               "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t(atom(), integer())"

      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec == "@type remote_t(a, b) :: {a, b}"
      assert suggestion.doc == "Remote type with params"
    end

    test "remote aliased type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:remote_aliased_o, buffer)

      assert suggestion.type_spec == "remote_aliased_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"

      assert suggestion.expanded_spec == """
             @type remote_aliased_t() ::
               ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()
               | ElixirSenseExample.ModuleWithTypespecs.Remote.remote_list_t()\
             """

      assert suggestion.doc == "Remote type from aliased module"
    end

    test "remote aliased inline type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:remote_aliased_inline_o, buffer)

      assert suggestion.type_spec == "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec == "@type remote_t() :: atom()"
      assert suggestion.doc == "Remote type"
    end

    test "inline list type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:inline_list_o, buffer)

      assert suggestion.type_spec == "[:trace | :log]"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == ""
    end

    test "non existent type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name(:non_existent_o, buffer)

      assert suggestion.type_spec ==
               "ElixirSenseExample.ModuleWithTypespecs.Remote.non_existent()"

      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == ""
    end

    test "named options" do
      buffer = "Local.func_with_named_options("
      assert suggestion_by_name(:local_o, buffer).type_spec == "local_t()"
    end

    test "options with only one option" do
      buffer = "Local.func_with_one_option("
      assert suggestion_by_name(:option_1, buffer).type_spec == "integer()"
    end

    test "union of options" do
      buffer = "Local.func_with_union_of_options("

      assert suggestion_by_name(:local_o, buffer).type_spec == "local_t()"
      assert suggestion_by_name(:option_1, buffer).type_spec == "atom()"
    end

    test "union of options inline" do
      buffer = "Local.func_with_union_of_options_inline("

      assert suggestion_by_name(:local_o, buffer).type_spec == "local_t()"
      assert suggestion_by_name(:option_1, buffer).type_spec == "atom()"
    end

    test "union of options (local and remote) as type + inline" do
      buffer = "Local.func_with_union_of_options_as_type("
      assert suggestion_by_name(:option_1, buffer).type_spec == "boolean()"

      suggestion = suggestion_by_name(:remote_option_1, buffer)
      assert suggestion.type_spec == "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()"
      assert suggestion.expanded_spec == "@type remote_t() :: atom()"
      assert suggestion.doc == "Remote type"
    end

    test "atom only options" do
      buffer = ":ets.new(:name,"

      assert suggestion_by_name(:duplicate_bag, buffer).type_spec == ""
      assert suggestion_by_name(:named_table, buffer).doc == ""
    end

    test "format type spec" do
      buffer = "Local.func_with_options("

      assert suggestion_by_name(:large_o, buffer).expanded_spec == """
             @type large_t() ::
               pid()
               | port()
               | (registered_name ::
                    atom())
               | {registered_name ::
                    atom(), node()}\
             """
    end
  end

  describe "suggestions for typespecs" do
    test "remote types - filter list of typespecs" do
      buffer = "Remote.remote_t"

      list = suggestions_by_type(:type_spec, buffer)
      assert length(list) == 2
    end

    test "remote types - retrieve info from typespecs" do
      buffer = "Remote."

      suggestion = suggestion_by_name(:remote_list_t, buffer)

      assert suggestion.spec == """
             @type remote_list_t() :: [
               remote_t()
             ]\
             """

      assert suggestion.signature == "remote_list_t()"
      assert suggestion.arity == 0
      assert suggestion.doc == "Remote list type"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
    end

    test "remote types - retrieve info from typespecs with params" do
      buffer = "Remote."

      [suggestion_1, suggestion_2] = suggestions_by_name(:remote_t, buffer)

      assert suggestion_1.spec == "@type remote_t() :: atom()"
      assert suggestion_1.signature == "remote_t()"
      assert suggestion_1.arity == 0
      assert suggestion_1.doc == "Remote type"
      assert suggestion_1.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"

      assert suggestion_2.spec == "@type remote_t(a, b) :: {a, b}"
      assert suggestion_2.signature == "remote_t(a, b)"
      assert suggestion_2.arity == 2
      assert suggestion_2.doc == "Remote type with params"
      assert suggestion_2.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
    end

    test "local types - filter list of typespecs" do
      buffer = """
      defmodule ElixirSenseExample.ModuleWithTypespecs.Local do
        # The types are defined in `test/support/module_with_typespecs.ex`
        @type my_type :: local_
        #                      ^
      end
      """

      list =
        ElixirSense.suggestions(buffer, 3, 26)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      assert length(list) == 2
    end

    test "local types - retrieve info from typespecs" do
      buffer = """
      defmodule ElixirSenseExample.ModuleWithTypespecs.Local do
        # The types are defined in `test/support/module_with_typespecs.ex`
        @type my_type :: local_t
        #                       ^
      end
      """

      list =
        ElixirSense.suggestions(buffer, 3, 27)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      [suggestion, _] = list

      assert suggestion.spec == "@type local_t() :: atom()"
      assert suggestion.signature == "local_t()"
      assert suggestion.arity == 0
      assert suggestion.doc == "Local type"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
    end

    test "builtin types - filter list of typespecs" do
      buffer = "@type my_type :: lis"

      list = suggestions_by_type(:type_spec, buffer)
      assert length(list) == 2
    end

    test "builtin types - retrieve info from typespecs" do
      buffer = "@type my_type :: lis"

      [suggestion | _] = suggestions_by_type(:type_spec, buffer)

      assert suggestion.spec == "@type list() :: [any()]"
      assert suggestion.signature == "list()"
      assert suggestion.arity == 0
      assert suggestion.doc == "A list"
      assert suggestion.origin == ""
    end

    test "builtin types - retrieve info from typespecs with params" do
      buffer = "@type my_type :: lis"

      [_, suggestion | _] = suggestions_by_type(:type_spec, buffer)

      assert suggestion.spec == ""
      assert suggestion.signature == "list(t)"
      assert suggestion.arity == 1
      assert suggestion.doc == "Proper list ([]-terminated)"
      assert suggestion.origin == ""
    end
  end

  defmodule ElixirSenseExample.SameModule do
    def test_fun(), do: :ok

    defmacro some_test_macro() do
      quote do
        @attr "val"
      end
    end
  end

  test "suggestion understands alias shadowing" do
    # ordinary alias
    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      alias ElixirSense.SuggestionsTest.ElixirSenseExample.SameModule
      def some_fun() do
        SameModule.te
      end
    end
    """

    assert [
             %{type: :hint, value: "SameModule.test_fun"},
             %{origin: "ElixirSense.SuggestionsTest.ElixirSenseExample.SameModule"}
           ] = ElixirSense.suggestions(buffer, 4, 17)

    # alias shadowing scope/inherited aliases
    buffer = """
    defmodule ElixirSenseExample.SameModule do
      alias List, as: SameModule
      alias ElixirSense.SuggestionsTest.ElixirSenseExample.SameModule
      def some_fun() do
        SameModule.te
      end
    end
    """

    assert [
             %{type: :hint, value: "SameModule.test_fun"},
             %{origin: "ElixirSense.SuggestionsTest.ElixirSenseExample.SameModule"}
           ] = ElixirSense.suggestions(buffer, 5, 17)

    buffer = """
    defmodule ElixirSenseExample.SameModule do
      require Logger, as: ModuleB
      require ElixirSense.SuggestionsTest.ElixirSenseExample.SameModule, as: SameModule
      SameModule.so
    end
    """

    assert [
             %{type: :hint, value: "SameModule.some_test_macro"},
             %{origin: "ElixirSense.SuggestionsTest.ElixirSenseExample.SameModule"}
           ] = ElixirSense.suggestions(buffer, 4, 15)
  end

  defp suggestions_by_type(type, buffer) do
    {line, column} = get_last_line_and_column(buffer)
    suggestions_by_type(type, buffer, line, column)
  end

  defp suggestions_by_type(type, buffer, line, column) do
    buffer
    |> add_aliases("Local, Remote")
    |> ElixirSense.suggestions(line + 1, column)
    |> Enum.filter(fn %{type: t} -> t == type end)
  end

  defp suggestions_by_name(name, buffer) do
    {line, column} = get_last_line_and_column(buffer)
    suggestions_by_name(name, buffer, line, column)
  end

  defp suggestions_by_name(name, buffer, line, column) do
    buffer
    |> add_aliases("Local, Remote")
    |> ElixirSense.suggestions(line + 1, column)
    |> Enum.filter(fn
      %{name: n} -> n == name
      _ -> false
    end)
  end

  defp suggestion_by_name(name, buffer) do
    {line, column} = get_last_line_and_column(buffer)
    suggestion_by_name(name, buffer, line, column)
  end

  defp suggestion_by_name(name, buffer, line, column) do
    [suggestion] = suggestions_by_name(name, buffer, line, column)
    suggestion
  end

  defp get_last_line_and_column(buffer) do
    str_lines = String.split(buffer, "\n")
    line = length(str_lines)
    column = (str_lines |> List.last() |> String.length()) + 1
    {line, column}
  end

  defp add_aliases(buffer, aliases) do
    "alias ElixirSenseExample.ModuleWithTypespecs.{#{aliases}}\n" <> buffer
  end
end

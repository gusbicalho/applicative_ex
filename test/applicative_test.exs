defmodule ApplicativeTest do
  use ExUnit.Case
  doctest Applicative

  test "greets the world" do
    assert Applicative.hello() == :world
  end
end

defmodule Brain2.Mind.BrainTest do
  use Brain2.DataCase, async: true

  alias Brain2.Mind

  test "creates a brain with a name" do
    assert {:ok, brain} = Mind.create_brain("Claude")
    assert brain.name == "Claude"
  end

  test "renames a brain" do
    {:ok, brain} = Mind.create_brain("Claude")
    assert {:ok, updated} = Mind.rename_brain(brain, "GPT-5")
    assert updated.name == "GPT-5"
  end

  test "name cannot be blank" do
    assert {:error, %Ash.Error.Invalid{}} = Mind.create_brain("")
  end
end

defmodule Brain2Web.BrainLiveTest do
  use Brain2Web.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Brain2.Mind
  alias Brain2.LLM.FakeAdapter

  setup do
    {:ok, brain} = Mind.create_brain("Claude")

    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "fear",
        level: 40,
        default_level: 0,
        prompt_injection: "You are afraid."
      })

    %{brain: brain}
  end

  test "renders three-column layout", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#chat-panel")
    assert has_element?(view, "#brain-admin-panel")
    assert has_element?(view, "#inner-panel")
  end

  test "shows system prompt panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#system-prompt-panel")
  end

  test "shows thought stream panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#thoughts-panel")
  end

  test "shows brain name in admin panel", %{conn: conn, brain: brain} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#brain-name", brain.name)
  end

  test "shows emotional states in admin panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#emotions-list")
    assert has_element?(view, "[data-emotion='fear']")
  end

  test "can rename the brain", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> element("#rename-form")
    |> render_submit(%{"name" => "GPT-5"})

    assert has_element?(view, "#brain-name", "GPT-5")
  end

  test "can adjust emotion level", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> element("[data-emotion='fear'] .level-form")
    |> render_change(%{"level" => "90"})

    assert has_element?(view, "[data-emotion='fear'] .level-display", "90")
  end

  test "system prompt includes injection when emotion level is active", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    # fear starts at 40 — its injection text should appear inside the system prompt pre
    assert has_element?(view, "#system-prompt-panel pre", "You are afraid.")
  end

  test "system prompt updates when emotion is raised from zero", %{conn: conn, brain: brain} do
    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "sadness",
        level: 0,
        default_level: 0,
        prompt_injection: "You feel a deep sadness."
      })

    {:ok, view, _html} = live(conn, "/")
    # sadness is at 0 — must NOT appear in the system prompt pre (it will appear in the card description, but not the prompt)
    refute has_element?(view, "#system-prompt-panel pre", "You feel a deep sadness.")

    view
    |> element("[data-emotion='sadness'] .level-form")
    |> render_change(%{"level" => "70"})

    assert has_element?(view, "#system-prompt-panel pre", "You feel a deep sadness.")
  end

  test "system prompt removes injection when emotion is set to zero", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#system-prompt-panel pre", "You are afraid.")

    view
    |> element("[data-emotion='fear'] .level-form")
    |> render_change(%{"level" => "0"})

    refute has_element?(view, "#system-prompt-panel pre", "You are afraid.")
  end

  test "can reset all emotions", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> element("#reset-emotions-btn")
    |> render_click()

    assert has_element?(view, "[data-emotion='fear'] .level-display", "0")
  end

  test "can send a chat message using stub LLM", %{conn: conn} do
    FakeAdapter.set_response("Hello! I am a test response.")

    {:ok, view, _html} = live(conn, "/")

    view
    |> element("#chat-form")
    |> render_submit(%{"message" => "Hi brain!"})

    assert has_element?(view, "#messages [data-role='user']", "Hi brain!")
    assert has_element?(view, "#messages [data-role='assistant']", "Hello! I am a test response.")
  end

  test "shows memory panel in inner world", %{conn: conn, brain: brain} do
    {:ok, _} = Brain2.Mind.store_memory(brain, "Test memory content.")
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#memories-panel")
    assert has_element?(view, "#memories-list [data-memory]", "Test memory content.")
  end

  test "input is cleared after sending a message", %{conn: conn} do
    FakeAdapter.set_response("Response.")
    {:ok, view, _html} = live(conn, "/")

    view
    |> element("#chat-form")
    |> render_submit(%{"message" => "Hello!"})

    refute has_element?(view, "#chat-input[value='Hello!']")
  end

  test "reset to start clears messages, thoughts, memories and resets emotions", %{conn: conn, brain: brain} do
    {:ok, _} = Mind.record_message(brain, :user, "Hello")
    {:ok, _} = Mind.record_thought(brain, "A thought")
    {:ok, _} = Mind.store_memory(brain, "Something remembered.")

    {:ok, view, _html} = live(conn, "/")

    view
    |> element("#reset-to-start-btn")
    |> render_click()

    refute has_element?(view, "#messages [data-role='user']", "Hello")
    refute has_element?(view, "#thoughts [data-role='thought']")
    refute has_element?(view, "#memories-list [data-memory]")
    assert has_element?(view, "[data-emotion='fear'] .level-display", "0")
  end

  test "emotion changes appear at end of thought when present", %{conn: conn, brain: brain} do
    {:ok, _} = Mind.add_emotion(brain, %{
      name: "curiosity",
      level: 50,
      default_level: 50,
      prompt_injection: "Curious."
    })
    {:ok, thought} = Mind.record_thought(brain, "Interesting question.")
    Mind.apply_emotion_changes(brain, [%{emotion: "curiosity", delta: 20, reason: "Engaging topic"}], thought.id)

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#thoughts [data-role='thought'] [data-changes]")
    assert has_element?(view, "#thoughts [data-role='thought'] [data-changes]", "curiosity")
  end

  test "generated memories shown with generated marker", %{conn: conn, brain: brain} do
    {:ok, _} = Mind.store_memory(brain, "I was pairing on a deploy. #generated")
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#memories-list [data-generated='true']")
  end

  test "thought appears in thought stream after message", %{conn: conn} do
    FakeAdapter.set_response("I am thinking about this.")

    {:ok, view, _html} = live(conn, "/")

    view
    |> element("#chat-form")
    |> render_submit(%{"message" => "Hi brain!"})

    assert has_element?(view, "#thoughts [data-role='thought']")
  end
end

module Examples.SharedStateDemo where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay, launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Yoga.JSON as JSON
import Yoga.Om.WorkerBees.SharedState as SharedState

type AppState =
  { counter :: Int
  , message :: String
  , isActive :: Boolean
  }

-- | Console demo of SharedState (JSON-serialized shared state with spinlock)
-- |
-- | This demonstrates:
-- | - Creating shared state with JSON serialization
-- | - Reading and writing shared state
-- | - Atomic modify operations
-- | - Spinlock-based synchronization
stateDemo :: Aff Unit
stateDemo = do
  log "=== Shared State Demo ==="
  log ""

  -- Create initial state
  let initialState :: AppState
      initialState =
        { counter: 0
        , message: "Hello"
        , isActive: true
        }

  log "Creating shared state..."
  log $ "Initial state: " <> JSON.writeJSON initialState

  -- Create shared state with 1KB buffer
  state <- liftEffect $ SharedState.new 1024 initialState

  -- Read the state
  log ""
  log "Reading state..."
  currentState <- liftEffect $ SharedState.read state
  log $ "Current state: " <> JSON.writeJSON currentState

  -- Modify the state atomically
  log ""
  log "Modifying state (increment counter, update message)..."
  _ <- liftEffect $ SharedState.modify state
    (\s -> s { counter = s.counter + 1, message = "Updated!" })

  -- Read again
  newState <- liftEffect $ SharedState.read state
  log $ "New state: " <> JSON.writeJSON newState

  -- Simulate concurrent modifications
  log ""
  log "Simulating concurrent modifications..."

  let modifyLoop :: Int -> Effect Unit
      modifyLoop n = do
        _ <- SharedState.modify state \s ->
          s { counter = s.counter + 1 }
        when (n > 0) $ modifyLoop (n - 1)

  -- Run 100 modifications
  liftEffect $ modifyLoop 100

  -- Small delay to ensure all modifications complete
  delay (Milliseconds 10.0)

  finalState <- liftEffect $ SharedState.read state
  log $ "After 100 modifications: " <> JSON.writeJSON finalState

  log ""
  log "Done!"

main :: Effect Unit
main = launchAff_ stateDemo

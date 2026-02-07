module Examples.SharedMapDemo where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Traversable (for_)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Yoga.JSON as JSON
import Yoga.Om.WorkerBees.SharedMap as SharedMap

type UserRecord =
  { id :: Int
  , name :: String
  , active :: Boolean
  }

-- | Console demo of SharedMap (concurrent hash map with striped locks)
-- |
-- | This demonstrates:
-- | - Creating a shared concurrent hash map
-- | - Insert, lookup, and modify operations
-- | - Thread-safe concurrent access
-- | - Striped lock-based synchronization
mapDemo :: Aff Unit
mapDemo = do
  log "=== Shared Map Demo ==="
  log ""

  -- Create shared map with 16 stripes and 4KB per entry
  log "Creating shared map (16 stripes, 4KB per entry)..."
  userMap <- liftEffect $ SharedMap.new 16 4096

  -- Insert some users
  log ""
  log "Inserting users..."

  let users =
        [ { id: 1, name: "Alice", active: true }
        , { id: 2, name: "Bob", active: false }
        , { id: 3, name: "Charlie", active: true }
        ]

  for_ users \user -> do
    let key = "user:" <> show user.id
    liftEffect $ SharedMap.insert key user userMap
    log $ "  Inserted: " <> key <> " -> " <> JSON.writeJSON user

  -- Lookup users
  log ""
  log "Looking up users..."

  for_ (Array.range 1 3) \userId -> do
    let key = "user:" <> show userId
    maybeUser <- liftEffect $ SharedMap.lookup key userMap
    case maybeUser of
      Just user -> log $ "  Found: " <> key <> " -> " <> JSON.writeJSON user
      Nothing -> log $ "  Not found: " <> key

  -- Modify a user
  log ""
  log "Modifying user:2 (set active = true)..."

  _ <- liftEffect $ SharedMap.modify "user:2" (\user -> user { active = true }) userMap

  -- Lookup the modified user
  maybeUser2 <- liftEffect $ SharedMap.lookup "user:2" userMap
  case maybeUser2 of
    Just user -> log $ "  Updated: " <> JSON.writeJSON user
    Nothing -> log "  User not found"

  -- Delete a user
  log ""
  log "Deleting user:1..."
  liftEffect $ SharedMap.delete "user:1" userMap

  -- Try to lookup deleted user
  maybeUser1 <- liftEffect $ SharedMap.lookup "user:1" userMap
  case maybeUser1 of
    Just _ -> log "  ERROR: User still exists!"
    Nothing -> log "  User successfully deleted"

  log ""
  log "Done!"

main :: Effect Unit
main = launchAff_ mapDemo

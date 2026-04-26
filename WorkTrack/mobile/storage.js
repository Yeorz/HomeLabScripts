import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';
import * as Keychain from 'react-native-keychain';

const WORKOUT_KEY = 'pending_workouts';
const TOKEN_SERVICE = 'com.worktrack.jwt';
const TOKEN_USERNAME = 'worktrack_user';

// Secure token storage using Keychain
export async function saveTokenSecurely(token) {
  try {
    await Keychain.setGenericPassword(TOKEN_USERNAME, token, {
      accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED,
      storage: Keychain.STORAGE_TYPE.KC_ITEM_ATTRIBUTE_VALUE_TYPE_SECURE_UTF8_STR,
    });
  } catch (error) {
    console.error('Failed to save token to Keychain:', error);
  }
}

export async function getTokenSecurely() {
  try {
    const credentials = await Keychain.getGenericPassword();
    return credentials ? credentials.password : null;
  } catch (error) {
    console.error('Failed to retrieve token from Keychain:', error);
    return null;
  }
}

export async function deleteTokenSecurely() {
  try {
    await Keychain.resetGenericPassword();
  } catch (error) {
    console.error('Failed to delete token from Keychain:', error);
  }
}

// Save workouts offline without token
export async function saveWorkoutOffline(workout) {
  try {
    const existing = JSON.parse(await AsyncStorage.getItem(WORKOUT_KEY)) || [];
    // Remove token from stored data
    const { token, ...workoutWithoutToken } = workout;
    existing.push({
      ...workoutWithoutToken,
      savedAt: new Date().toISOString(),
    });
    await AsyncStorage.setItem(WORKOUT_KEY, JSON.stringify(existing));
  } catch (error) {
    console.error('Failed to save workout offline:', error);
  }
}

// Sync workouts - fetch token at sync time
export async function syncPendingWorkouts() {
  try {
    const token = await getTokenSecurely();  // Retrieve token from Keychain
    if (!token) {
      console.error('No token available for sync');
      return;
    }

    const existing = JSON.parse(await AsyncStorage.getItem(WORKOUT_KEY)) || [];
    if (existing.length === 0) return;

    const state = await NetInfo.fetch();
    if (!state.isConnected) return;

    const remaining = [];
    for (let workout of existing) {
      try {
        const res = await fetch("http://localhost:8080/workouts", {
          method: "POST",
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`
          },
          body: JSON.stringify(workout)
        });
        if (!res.ok) remaining.push(workout);
      } catch {
        remaining.push(workout);
      }
    }
    await AsyncStorage.setItem(WORKOUT_KEY, JSON.stringify(remaining));
  } catch (error) {
    console.error('Sync failed:', error);
  }
}
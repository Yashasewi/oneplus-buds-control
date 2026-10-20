import { useSyncExternalStore } from "react";
import { BudsSession } from "./session";

export const session = new BudsSession((event, details) => {
  if (import.meta.env.DEV) console.debug(event, details ?? "");
});

export function useBuds() {
  return useSyncExternalStore(session.subscribe, session.getSnapshot);
}

// After the user presses Disconnect, stay disconnected until they connect again.
let userDisconnected = false;
export async function connect() {
  userDisconnected = false;
  await session.connect(await session.choose());
}
export function disconnect() {
  userDisconnected = true;
  void session.close("You disconnected.");
}
async function autoConnect() {
  const { connection } = session.snapshot;
  if (
    userDisconnected ||
    session.connected ||
    connection === "connecting" ||
    connection === "restarting"
  )
    return;
  const port = await session.grantedPort();
  if (port) await session.connect(port, { quiet: true }).catch(() => {});
}
// Only some changes are pushed by the earbuds; others (gestures, switches changed on the phone) need a read.
function rereadOnReturn() {
  if (document.visibilityState !== "visible" || !session.connected || action.phase === "pending")
    return;
  if (Date.now() - session.lastRefresh < 15000) return;
  void session.refresh().catch(() => {});
}
let started = false;
export function startBackground() {
  if (started) return;
  started = true;
  void autoConnect();
  navigator.serial?.addEventListener("connect", () => void autoConnect());
  document.addEventListener("visibilitychange", rereadOnReturn);
  window.addEventListener("focus", rereadOnReturn);
}

// One change at a time: a write and its read-back must not interleave with another write.
export type Phase = "pending" | "done" | "error";
export interface ActionState {
  key: string | null;
  phase?: Phase;
  message?: string;
}
let action: ActionState = { key: null };
const actionListeners = new Set<() => void>();
let clearTimer: ReturnType<typeof setTimeout> | undefined;
function setAction(next: ActionState) {
  action = next;
  actionListeners.forEach((l) => l());
}
const subscribeAction = (l: () => void) => {
  actionListeners.add(l);
  return () => actionListeners.delete(l);
};

export async function run<T>(
  key: string,
  work: () => Promise<T>,
  success?: string | ((result: T) => string),
) {
  if (action.phase === "pending" || !session.connected) return;
  clearTimeout(clearTimer);
  setAction({ key, phase: "pending" });
  try {
    const result = await work();
    setAction({
      key,
      phase: "done",
      message: typeof success === "function" ? success(result) : success,
    });
    clearTimer = setTimeout(() => setAction({ key: null }), success ? 6000 : 1800);
    return result;
  } catch (error) {
    setAction({ key, phase: "error", message: (error as Error).message });
    clearTimer = setTimeout(() => setAction({ key: null }), 9000);
  }
}

export function useAction(key?: string) {
  const current = useSyncExternalStore(subscribeAction, () => action);
  const busy = current.phase === "pending";
  return { busy, status: key && current.key === key ? current : undefined };
}

// Promise-based confirmation, rendered by <ConfirmHost/>.
export interface ConfirmRequest {
  title: string;
  body: string;
  action: string;
  resolve(ok: boolean): void;
}
let confirmRequest: ConfirmRequest | null = null;
const confirmListeners = new Set<() => void>();
export function confirm(title: string, body: string, actionLabel = "Continue") {
  return new Promise<boolean>((resolve) => {
    confirmRequest = {
      title,
      body,
      action: actionLabel,
      resolve: (ok) => {
        confirmRequest = null;
        confirmListeners.forEach((l) => l());
        resolve(ok);
      },
    };
    confirmListeners.forEach((l) => l());
  });
}
export function useConfirmRequest() {
  return useSyncExternalStore(
    (l) => {
      confirmListeners.add(l);
      return () => confirmListeners.delete(l);
    },
    () => confirmRequest,
  );
}

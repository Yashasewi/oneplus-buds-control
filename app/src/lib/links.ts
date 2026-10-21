export const REPO = "https://github.com/Yashasewi/oneplus-buds-control";
export const RELEASES = `${REPO}/releases`;
export const ISSUES = `${REPO}/issues/new/choose`;
export const MAC_DMG = `${REPO}/releases/latest/download/OpenBuds.dmg`;
const LATEST_API = "https://api.github.com/repos/Yashasewi/oneplus-buds-control/releases/latest";

export type Release = { tag: string; date: Date; size?: number; url: string };

let cached: Promise<Release | undefined> | undefined;

/** The newest GitHub release, fetched once per page load. */
export function latestRelease() {
  cached ??= fetch(LATEST_API, { headers: { Accept: "application/vnd.github+json" } })
    .then((r) => (r.ok ? r.json() : undefined))
    .then((json) => {
      if (!json?.tag_name) return undefined;
      const dmg = (json.assets as { name: string; size: number }[] | undefined)?.find(
        (a) => a.name === "OpenBuds.dmg",
      );
      return {
        tag: json.tag_name as string,
        date: new Date(json.published_at),
        size: dmg?.size,
        url: json.html_url as string,
      };
    })
    .catch(() => undefined);
  return cached;
}

# Aperture Docs

Documentation site for the Aperture capstone, built with [Fumadocs](https://www.fumadocs.dev) (Next.js static export) and published to GitHub Pages at https://arnav57.github.io/aperture/.

## Prerequisites

- [Node.js](https://nodejs.org) 22 or newer (check with `node -v`)
- npm (ships with Node)
- Git

## Getting started

From the repo root:

```bash
cd docs
npm install
npm run dev
```

Open http://localhost:3000. The dev server hot-reloads, so edits to pages show up as you save.

## Writing docs

- Pages are MDX files under `content/docs/`. Add a new `.mdx` file there and it becomes a page.
- Each page needs frontmatter at the top:

  ```mdx
  ---
  title: Page Title
  description: One-line summary
  ---
  ```

- To control sidebar order and grouping, edit the `meta.json` file in the folder.
- Put images in `public/` and reference them by path (for example `/diagram.png`).

## Checking a production build

The site is a static export, so it's worth confirming the build passes before pushing:

```bash
npm run build
npx serve out
```

Then open the URL that `serve` prints. This builds without the `/aperture` base path, so it checks that the export works, not the subpath. The real subpath is tested by the deploy.

Common build failures:

- A broken link or a bad MDX syntax error in a page (the error names the file).
- A server-only route (anything that needs a running server can't be exported).

## Deployment

Pushing to `main` triggers the GitHub Actions workflow in `.github/workflows/docs.yml`, which builds the site with the `/aperture` base path and deploys it to GitHub Pages. There is nothing to deploy manually.

If a deployed page loads without styling or assets, the base path is almost always the cause. Check `basePath` in `next.config.mjs`.

## Troubleshooting

- **`npm install` errors:** Confirm your Node version, then delete `node_modules` and try again.
- **Port 3000 in use:** Run `npm run dev -- -p 3001`.
- **Search returns nothing locally:** Search is built from a static index, so run `npm run build` once and check again.
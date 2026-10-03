import { defineConfig } from 'fumadocs-mdx/config';
import { remarkMdxMermaid } from 'fumadocs-core/mdx-plugins';
import rehypeKatex from 'rehype-katex';
import remarkMath from 'remark-math';

export default defineConfig({
  mdxOptions: {
    remarkPlugins: [remarkMdxMermaid, remarkMath],
    rehypePlugins: (v) => [rehypeKatex, ...v],
  },
});
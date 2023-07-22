import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import Unfonts from 'unplugin-fonts/vite';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), Unfonts({
    // Custom fonts.
    custom: {
      /**
       * Fonts families lists
       */
      families: [{
        /**
         * Name of the font family.
         */
        name: 'Kobuzan',
        /**
         * Local name of the font. Used to add `src: local()` to `@font-rule`.
         */
        local: 'Kobuzan',
        /**
         * Regex(es) of font files to import. The names of the files will
         * predicate the `font-style` and `font-weight` values of the `@font-rule`'s.
         */
        src: './src/assets/*.otf',
      }]}})]
})

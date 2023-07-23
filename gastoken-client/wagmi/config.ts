import { defineConfig } from "@wagmi/cli";
import { react } from "@wagmi/cli/plugins";
import { erc } from "@wagmi/cli/plugins";
import borrowerOperationsABI from "./abi/borrowerOperations.json";
import hintHelpersABI from "./abi/hintHelpers.json";
import troveManagerABI from "./abi/troveManager.json";
import elFamosoContractABI from "./abi/elFamosoContract.json";

export default defineConfig({
  out: "src/contract/generated.ts",
  contracts: [
    {
        name: "Borrower Operations",
        // @ts-ignore
        abi: borrowerOperationsABI,
    },
    {
        name: "Hint Helpers",
        // @ts-ignore
        abi: hintHelpersABI,
    },
    {
        name: "Trove Manager",
        // @ts-ignore
        abi: troveManagerABI
    },
    {
        name: "El Famoso Contract",
        // @ts-ignore
        abi: elFamosoContractABI
    }
  ],
  plugins: [
    erc({
      20: true,
    }),
    react(),
  ],
});

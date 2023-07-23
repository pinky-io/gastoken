import { parseEther } from "viem";
import { useHintHelpersGetRedemptionHints } from "../../contract/generated";
import { addressConfig } from "../../contract/addressConfig";
import { useEffect, useState } from "react";

export const useRedeem = (baseFee: number, gasToRedeem: number) => {
  const [args, setArgs] = useState<[bigint, bigint, bigint]>([]);

  const {
    data: hintHelperData,
    fetchStatus,
    refetch,
    isFetched,
  } = useHintHelpersGetRedemptionHints({
    address: addressConfig.hintHelper,
    args,
    enabled: false,
  });

  useEffect(() => {
    async function fetchData(): Promise<void> {
      const res = await refetch();

      console.log({ res });

      setArgs([
        BigInt(parseEther(gasToRedeem.toString(), "wei")),
        BigInt(Math.round(baseFee * 1000000)),
        BigInt(0),
      ]);
    }

    fetchData();
  }, [baseFee, gasToRedeem, refetch]);

  return { fetchStatus, hintHelperData, isFetched };
};

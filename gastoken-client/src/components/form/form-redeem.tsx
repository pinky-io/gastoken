import { useEffect, useState } from "react";
import "./form.css";
import parameters from "../../data/geth_parameters";
import { getGETHBaseFee } from "../../service/wallet.service";
import {
  useBorrowerOperationsCloseTrove,
} from "../../contract/generated";
import { addressConfig } from "../../contract/addressConfig";
import { useWaitForTransaction } from "wagmi";

function formatGweiPrice(priceGwei: number): number {
  return parseFloat(priceGwei.toFixed(4));
}

function computeRedeemingFee(redeemedGasETH: number): number {
  return parseFloat((parameters.borrowingFee * redeemedGasETH).toFixed(6));
}

const FormRedeemComponent = () => {
  const [gETHBaseFee, setGETHBaseFee] = useState<number>(0);
  const [gasETHToRedeem, setGasETHToRedeem] = useState<number>();
  const { writeAsync, data } = useBorrowerOperationsCloseTrove({
    address: addressConfig.borrowerOperations,
  });

  const { isLoading } = useWaitForTransaction({
    hash: data?.hash,
  });

  useEffect(() => {
    async function fetchData(): Promise<void> {
      const baseFee = await getGETHBaseFee();
      setGETHBaseFee(baseFee);
    }
    fetchData();
  }, []);

  const handleGasETHInputChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const newValue = Number(event.target.value);
    setGasETHToRedeem(newValue);
  };

  async function handleRedeemCollateral() {
    if (gasETHToRedeem) {
      await writeAsync?.({});
    }
  }

  return (
    <>
      <div className="flex justify-between">
        <div className="flex flex-col justify-between">
          <div className="flex flex-col">
            <label className="text-white">gasETH to redeem :</label>
            <input
              type="number"
              placeholder="Enter a collateral in ETH"
              className="p-[4px] bg-[#CBD5E0] rounded-sm"
              value={gasETHToRedeem || ""}
              onChange={handleGasETHInputChange}
            ></input>
          </div>
        </div>
        <div className="flex flex-col">
          <div className="bg-[#CBD5E0] rounded-lg p-[12px]">
            <p>
              SP95 base fee price :{" "}
              {gETHBaseFee && formatGweiPrice(gETHBaseFee)} gwei
            </p>
            <p>Redeemed gasETH : {gasETHToRedeem}</p>
            <p>
              Redeeming fee :{" "}
              {gasETHToRedeem && computeRedeemingFee(gasETHToRedeem)}
            </p>
          </div>
        </div>
      </div>
      <div className="flex justify-end">
        <button
          className="mt-[12px] bg-[#93F5FF] hover:border-[#93F5FF]"
          onClick={handleRedeemCollateral}
        >
          {isLoading ? "Loading..." : "Close"}
        </button>
      </div>
    </>
  );
};

export default FormRedeemComponent;

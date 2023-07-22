import { useEffect, useState } from "react";
import './form.css';
import parameters from '../../data/geth_parameters';
import { getGETHBaseFee } from "../../service/wallet.service";

function formatPercentage(percentage: number): string {
    return `${percentage * 100}%`;
}

function formatGweiPrice(priceGwei: number): number {
    return parseFloat(priceGwei.toFixed(4));
}

function computeReceivedGas(collateral: number, collateralizationRatio: number, gETHBaseFee: number): number {
    return parseFloat(((collateral * Math.pow(10, 3))/(collateralizationRatio * gETHBaseFee)).toFixed(2)); // in gwei
}

function computeBorrowingFee(collateral: number, collateralizationRatio: number, gETHBaseFee: number): number {
    return computeReceivedGas(collateral, collateralizationRatio, gETHBaseFee) * parameters.borrowingFee * Math.pow(10, -9); //in eth
}

function computeBaseFeeLiquidation(gETHBaseFee: number): number {
    return parseFloat(((parameters.collateralizationRatio / parameters.minCollateralizationRatio) * gETHBaseFee).toFixed(4));
}

const FormBorrowComponent = () => {
    const [collateralValue, setCollateralValue] = useState<number>(0);
    const [gETHBaseFee, setGETHBaseFee] = useState<number>();
    const [receivedGas, setReceivedGas] = useState<number>();
    const [borrowingFee, setBorrowingFee] = useState<number>();
    const [baseFeeLiquidation, setBaseFeeLiquidation] = useState<number>();

    useEffect(() => {
        setReceivedGas(gETHBaseFee ? computeReceivedGas(collateralValue, parameters.collateralizationRatio, gETHBaseFee) : undefined);
        setBorrowingFee(gETHBaseFee ? computeBorrowingFee(collateralValue, parameters.collateralizationRatio, gETHBaseFee) : undefined);
        setBaseFeeLiquidation(gETHBaseFee ? computeBaseFeeLiquidation(gETHBaseFee) : undefined);
    }, [collateralValue, gETHBaseFee]);



    useEffect(() => {
        async function fetchData(): Promise<void> {
            const baseFee = await getGETHBaseFee();
            setGETHBaseFee(baseFee);
        }
        fetchData();
    }, []);

    const handleCollateralInputChange = (event) => {
      const newValue = event.target.value;
      setCollateralValue(newValue);
      setReceivedGas(gETHBaseFee ? computeReceivedGas(collateralValue, parameters.collateralizationRatio, gETHBaseFee) : undefined);
      setBorrowingFee(gETHBaseFee ? computeBorrowingFee(collateralValue, parameters.collateralizationRatio, gETHBaseFee) : undefined);
      setBaseFeeLiquidation(gETHBaseFee ? computeBaseFeeLiquidation(gETHBaseFee) : undefined);
    };

    const handleDebtInputChange = (event) => {
        const newValue = event.target.value;
        setReceivedGas(newValue);
    };

  return (
    <>
        <div className="flex justify-between">
            <div className="flex flex-col justify-between">
                <div className="flex flex-col">
                    <label className="text-white">Collateral in ETH :</label>
                    <input type="number" placeholder="Enter a collateral in ETH" className="p-[4px] bg-[#CBD5E0] rounded-sm" value={collateralValue || ''} onChange={handleCollateralInputChange}></input>
                </div>
                <div className="flex flex-col">
                    <label className="text-white">Debt :</label>
                    <input placeholder="Enter an amount of gas" className="p-[4px] bg-[#CBD5E0] rounded-sm" value={receivedGas || ''} onChange={handleDebtInputChange}></input>
                </div>
            </div>
            <div className="flex flex-col">
                <div className="bg-[#CBD5E0] rounded-lg p-[12px]">
                    <p>Collateral : { collateralValue }</p>
                    <p>Received gasETH : { receivedGas }</p>
                    <p>Collateralization ratio (min. { formatPercentage(parameters.minCollateralizationRatio) }) : { formatPercentage(parameters.collateralizationRatio) }</p>
                    <p>Borrowing fee : { borrowingFee } ETH</p>
                    <p>SP95 base fee price : { gETHBaseFee && formatGweiPrice(gETHBaseFee) } gwei</p>
                    <p>Base fee liquidation treshold : { baseFeeLiquidation } gwei</p>
                </div>
            </div>
        </div>
        <div className="flex justify-end">
            <button className="mt-[12px] bg-[#93F5FF] hover:border-[#93F5FF]">Borrow</button>
        </div>
    </>
  );
};

export default FormBorrowComponent;
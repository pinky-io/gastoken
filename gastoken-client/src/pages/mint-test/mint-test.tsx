import "./mint-test.css";
import nftImage from "../../assets/nft_image.jpeg";
import { useElFamosoContractMint } from "../../contract/generated";
import { addressConfig } from '../../contract/addressConfig';

const MintPage = () => {
  // value : 0, quantité que tu veux mint : 1
  const { data, write } = useElFamosoContractMint({
    address: addressConfig.famosoNft,
  });

  const minNft = () => {
    write({ args: [1] });
  }

  return (
    <div className="flex justify-center mt-[120px]">
      <div className="perspective-div">
        <img src={nftImage} className="logo react" alt="React logo" />
      </div>
      <div className="ml-[16px] flex flex-col justify-between py-[16px]">
        <p className="text-white">
          <span className="text-xl font-semibold">My super swag NFT</span>
          <br></br>
          <span className="text-base font-light">#09090B</span>
        </p>
        <button
          onClick={minNft}
          className="rounded-3xl w-[250px] mt-[28px] bg-indigo-500 text-slate-50 button-gradient"
        >
          MINT
        </button>
      </div>
    </div>
  );
};

export default MintPage;

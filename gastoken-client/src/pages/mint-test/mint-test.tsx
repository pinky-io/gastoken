import './mint-test.css';
import nftImage from '../../assets/nft_image.jpeg';

const MintPage = () => {
  return (
    <div className='flex justify-center'>
        <div className='perspective-div'>
            <img src={nftImage} className="logo react" alt="React logo" />
        </div>
        <div className='ml-[16px] flex flex-col justify-between py-[16px]'>
            <p className='text-white'><span className='text-xl font-semibold'>My super swag NFT</span><br></br><span className='text-base font-light'>#09090B</span></p>
            <button className='rounded-3xl w-[250px] mt-[28px] bg-indigo-500 text-slate-50 button-gradient'>MINT</button>
        </div>
    </div>
  );
};

export default MintPage;
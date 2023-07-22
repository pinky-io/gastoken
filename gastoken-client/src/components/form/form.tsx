import { useState } from 'react';
import FormBorrowComponent from './form-borrow';
import './form.css';
import FormRedeemComponent from './form-redeem';

const FormComponent = () => {

    const [borrow, setBorrow] = useState<boolean>(true);

    const handleClick = (borrow: boolean): void => {
        setBorrow(borrow);
    }

  return (
    <div className="bg-[#434751] rounded-xl relative my-[180px] p-[12px]">
        <div className="bg-[#09090B] h-[40px] t-toggle-container rounded-xl h-[36px] flex items-center text-white p-[2px]">
            <p className={ `h-full flex items-center justify-center font-semibold w-[100px] ${borrow ? 'bg-[#CBD5E0] rounded-xl ' : 'px-[4px] mx-[6px]' }` } onClick={() => handleClick(true)}>BORROW</p>
            <p className={ `h-full flex items-center justify-center font-semibold w-[100px] ${!borrow ? 'bg-[#CBD5E0] rounded-xl ' : 'px-[4px] mx-[6px]' }` } onClick={() => handleClick(false)}>REDEEM</p>
        </div>
        <p className='w-full text-center mt-[26px] mb-[12px] text-[#CBD5E0]'>SP95 gasETH is an ERC-20 token that follows the 7-day moving average of the Ethereum base fee</p>
        { borrow ? <FormBorrowComponent /> : <FormRedeemComponent />}
    </div>
  );
};

export default FormComponent;

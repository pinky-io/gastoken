import ChartComponent from '../../components/chart-component/chart-component';
import FormComponent from '../../components/form/form';

const HomePage = () => {
  return (
    <div className='flex flex-col items-center'>
        <div className='flex justify-between w-4/5 ml-auto mr-auto mt-[60px]'>
            <div className='flex flex-col justify-center pr-[40px]'>
                <h1 className='text-4xl mb-[8px] text-[#93F5FF]' style={{ fontFamily: 'Kobuzan' }}>Taking the Edge off<br></br>Ethereum Gas Prices</h1>
                <p className='mb-[50px] text-white'>We are an innovative gas hedging protocol, ensuring that the cost of your actions on the Ethereum blockchain remains stable over time. Experience the freedom of conducting transactions without worrying about unpredictable gas fees</p>
                <button className='w-[160px] bg-[#93F5FF] hover:border-[#93F5FF]'>Use $gasETH</button>
            </div>

            <ChartComponent />
        </div>
        <FormComponent />
    </div>
  );
};

export default HomePage;

import { LineChart, Line, CartesianGrid, Legend } from 'recharts';
import AvgGasPrice from '../../data/avg_gas_price.json';

const avgDayBasis = 7;

const renderLegend = (props) => {
  const { payload } = props;

  return (
    <div className='flex justify-center align-center gap-[16px]'>
      {payload.map((entry, index) => (
        <span key={`item-${index}`} style={{ color: entry.color }}>
          {index === 0 ? 'Average Gas Fee' : '$gasETH Price'}
        </span>
      ))}
    </div>
  );
};

const getAvgGasPrice = (index: number) => {
  return AvgGasPrice.slice(index - avgDayBasis, index).map((gp) => gp.value).reduce((a, b) => a + b) / avgDayBasis;
}

const ChartComponent = () => {
    const data = AvgGasPrice.slice(7).map((avgGasPrice, index) => {
      return { name: avgGasPrice.date, line1: avgGasPrice.value, line2: getAvgGasPrice(index + avgDayBasis)};
    });

    return (
      <LineChart width={500} height={300} data={data}>
        <CartesianGrid stroke="none" strokeDasharray="none" />
        <Legend content={renderLegend} />
        <Line type="monotone" dataKey="line1" stroke="#8884d8" animationDuration={5000} dot={false} />
        <Line type="monotone" dataKey="line2" stroke="#93F5FF" animationDuration={5000} dot={false} />
      </LineChart>
    );
};

export default ChartComponent;

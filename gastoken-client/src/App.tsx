import { Route, BrowserRouter as Router, Routes } from 'react-router-dom';
import './style/global.css';
import Header from './components/header/header';
import MintPage from './pages/mint-test/mint-test';
import HomePage from './pages/home/home';

function App() {
  return (
    <>
      <Router>
        <Header />
        <Routes>
          <Route path="/" Component={HomePage} />
          <Route path="/nft" Component={MintPage} />
        </Routes>
      </Router>
    </>
  )
}

export default App

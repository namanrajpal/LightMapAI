import { Routes, Route } from 'react-router-dom'
import { CandleFlame } from './scenes/CandleFlame'
import { CosmicGeometry } from './scenes/CosmicGeometry'
import { CosmicGeometry2 } from './scenes/CosmicGeometry2'
import { BlackFlicker } from './scenes/BlackFlicker'
import { NeonRedPulse } from './scenes/NeonRedPulse'
import { GreenCreative } from './scenes/GreenCreative'
import { SceneIndex } from './scenes/SceneIndex'

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<SceneIndex />} />
      <Route path="/candle" element={<CandleFlame />} />
      <Route path="/cosmic" element={<CosmicGeometry />} />
      <Route path="/cosmic2" element={<CosmicGeometry2 />} />
      <Route path="/black-flicker" element={<BlackFlicker />} />
      <Route path="/neon-red" element={<NeonRedPulse />} />
      <Route path="/green-creative" element={<GreenCreative />} />
    </Routes>
  )
}

import { Link } from 'react-router-dom'
import scenes from './registry'

export function SceneIndex() {
  return (
    <div style={{
      background: '#111',
      color: '#fff',
      minHeight: '100vh',
      padding: '2rem',
      fontFamily: 'system-ui, sans-serif',
    }}>
      <h1 style={{ marginBottom: '1rem' }}>Projection Surfaces</h1>
      <p style={{ color: '#888', marginBottom: '2rem' }}>
        Each scene runs at its own route. Load them in Godot via the 🌐 button.
      </p>
      <div style={{ display: 'grid', gap: '1rem', maxWidth: '500px' }}>
        {scenes.map(s => (
          <Link
            key={s.id}
            to={s.path}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '1rem',
              padding: '1rem',
              background: '#222',
              borderRadius: '8px',
              color: '#fff',
              textDecoration: 'none',
              border: '1px solid #333',
            }}
          >
            <span style={{ fontSize: '2rem' }}>{s.emoji}</span>
            <div>
              <div style={{ fontWeight: 'bold' }}>{s.name}</div>
              <div style={{ color: '#888', fontSize: '0.85rem' }}>{s.description}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

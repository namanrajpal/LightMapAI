import * as THREE from 'three'
import { useThreeScene } from './useThreeScene'

const PARTICLE_COUNT = 500

export function CandleFlame() {
  const positions = new Float32Array(PARTICLE_COUNT * 3)
  const velocities = new Float32Array(PARTICLE_COUNT * 3)
  const lifetimes = new Float32Array(PARTICLE_COUNT)
  const maxLifetimes = new Float32Array(PARTICLE_COUNT)
  const sizes = new Float32Array(PARTICLE_COUNT)
  let flameMat: THREE.PointsMaterial
  let flameGeo: THREE.BufferGeometry
  let innerGlow: THREE.Mesh
  let outerGlow: THREE.Mesh
  let topGlow: THREE.Mesh

  function resetParticle(i: number) {
    // Spawn across the bottom of the view
    positions[i * 3] = (Math.random() - 0.5) * 1.2
    positions[i * 3 + 1] = -1.5 + Math.random() * 0.3
    positions[i * 3 + 2] = (Math.random() - 0.5) * 0.3
    // Rise upward with slight horizontal drift
    velocities[i * 3] = (Math.random() - 0.5) * 0.4
    velocities[i * 3 + 1] = 1.5 + Math.random() * 2.0
    velocities[i * 3 + 2] = (Math.random() - 0.5) * 0.2
    lifetimes[i] = 0
    maxLifetimes[i] = 0.5 + Math.random() * 1.0
    sizes[i] = 0.15 + Math.random() * 0.25
  }

  for (let i = 0; i < PARTICLE_COUNT; i++) resetParticle(i)

  const containerRef = useThreeScene({
    cameraPosition: [0, 0, 3],
    cameraLookAt: [0, 0, 0],
    setup(scene) {
      // Flame particles
      flameGeo = new THREE.BufferGeometry()
      flameGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3))

      flameMat = new THREE.PointsMaterial({
        size: 0.2,
        color: 0xffaa33,
        transparent: true,
        opacity: 0.85,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
        sizeAttenuation: true,
      })
      scene.add(new THREE.Points(flameGeo, flameMat))

      // Hot white core glow at bottom center
      innerGlow = new THREE.Mesh(
        new THREE.SphereGeometry(0.4, 16, 16),
        new THREE.MeshBasicMaterial({
          color: 0xffffee,
          transparent: true,
          opacity: 0.6,
          blending: THREE.AdditiveBlending,
        })
      )
      innerGlow.position.y = -1.0
      scene.add(innerGlow)

      // Orange mid glow
      outerGlow = new THREE.Mesh(
        new THREE.SphereGeometry(0.8, 16, 16),
        new THREE.MeshBasicMaterial({
          color: 0xff6600,
          transparent: true,
          opacity: 0.25,
          blending: THREE.AdditiveBlending,
        })
      )
      outerGlow.position.y = -0.5
      scene.add(outerGlow)

      // Upper tip glow
      topGlow = new THREE.Mesh(
        new THREE.SphereGeometry(0.3, 12, 12),
        new THREE.MeshBasicMaterial({
          color: 0xff4400,
          transparent: true,
          opacity: 0.15,
          blending: THREE.AdditiveBlending,
        })
      )
      topGlow.position.y = 0.5
      scene.add(topGlow)
    },
    animate(t, dt) {
      for (let i = 0; i < PARTICLE_COUNT; i++) {
        lifetimes[i] += dt
        if (lifetimes[i] > maxLifetimes[i]) {
          resetParticle(i)
          continue
        }
        const life = lifetimes[i] / maxLifetimes[i]

        // Rise and slow down, narrow toward top
        positions[i * 3] += velocities[i * 3] * dt * (1 - life * 0.7)
        positions[i * 3 + 1] += velocities[i * 3 + 1] * dt * (1 - life * 0.3)
        positions[i * 3 + 2] += velocities[i * 3 + 2] * dt * (1 - life * 0.7)

        // Wind sway
        positions[i * 3] += Math.sin(t * 2.5 + i * 0.3) * 0.003
        positions[i * 3 + 2] += Math.cos(t * 1.8 + i * 0.5) * 0.001
      }
      flameGeo.attributes.position.needsUpdate = true

      // Flicker
      flameMat.opacity = 0.6 + Math.random() * 0.3
      flameMat.size = 0.18 + Math.sin(t * 6) * 0.04

      // Glow pulse
      innerGlow.scale.setScalar(0.9 + Math.sin(t * 7) * 0.15)
      ;(innerGlow.material as THREE.MeshBasicMaterial).opacity = 0.4 + Math.random() * 0.3
      outerGlow.scale.set(
        0.9 + Math.sin(t * 3) * 0.15,
        1.0 + Math.sin(t * 5) * 0.2,
        0.9 + Math.cos(t * 4) * 0.1
      )
      topGlow.position.y = 0.4 + Math.sin(t * 4) * 0.15
      topGlow.scale.setScalar(0.8 + Math.sin(t * 6) * 0.2)
    },
  })

  return <div ref={containerRef} style={{ width: '100vw', height: '100vh' }} />
}

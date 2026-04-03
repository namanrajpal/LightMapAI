import * as THREE from 'three'
import { useThreeScene } from './useThreeScene'

export function CosmicGeometry() {
  let ico: THREE.Mesh
  let icoMat: THREE.MeshBasicMaterial
  let core: THREE.Mesh
  let coreMat: THREE.MeshStandardMaterial
  const rings: THREE.Mesh[] = []
  let stars: THREE.Points
  const orbiters: { mesh: THREE.Mesh; radius: number; speed: number; phase: number; tilt: number }[] = []
  let camera: THREE.PerspectiveCamera

  const containerRef = useThreeScene({
    cameraPosition: [0, 0, 6],
    background: 0x050510,
    setup(scene, cam) {
      camera = cam
      scene.fog = new THREE.FogExp2(0x050510, 0.08)

      // Central icosahedron wireframe
      icoMat = new THREE.MeshBasicMaterial({ color: 0x4488ff, wireframe: true, transparent: true, opacity: 0.6 })
      ico = new THREE.Mesh(new THREE.IcosahedronGeometry(1.2, 1), icoMat)
      scene.add(ico)

      // Inner core
      coreMat = new THREE.MeshStandardMaterial({
        color: 0x8844ff, emissive: 0x4422aa, emissiveIntensity: 0.5, roughness: 0.3, metalness: 0.8,
      })
      core = new THREE.Mesh(new THREE.IcosahedronGeometry(0.5, 2), coreMat)
      scene.add(core)

      // Orbiting rings
      const ringColors = [0xff4488, 0x44ff88, 0xffaa22, 0x22aaff]
      for (let i = 0; i < 4; i++) {
        const ring = new THREE.Mesh(
          new THREE.TorusGeometry(1.8 + i * 0.4, 0.015, 8, 80),
          new THREE.MeshBasicMaterial({ color: ringColors[i], transparent: true, opacity: 0.5 })
        )
        ring.rotation.x = Math.random() * Math.PI
        ring.rotation.y = Math.random() * Math.PI
        scene.add(ring)
        rings.push(ring)
      }

      // Stars
      const STAR_COUNT = 300
      const starPositions = new Float32Array(STAR_COUNT * 3)
      for (let i = 0; i < STAR_COUNT; i++) {
        const theta = Math.random() * Math.PI * 2
        const phi = Math.acos(2 * Math.random() - 1)
        const r = 3 + Math.random() * 8
        starPositions[i * 3] = r * Math.sin(phi) * Math.cos(theta)
        starPositions[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta)
        starPositions[i * 3 + 2] = r * Math.cos(phi)
      }
      const starGeo = new THREE.BufferGeometry()
      starGeo.setAttribute('position', new THREE.BufferAttribute(starPositions, 3))
      stars = new THREE.Points(starGeo, new THREE.PointsMaterial({
        size: 0.04, color: 0xffffff, transparent: true, opacity: 0.8,
        blending: THREE.AdditiveBlending, depthWrite: false, sizeAttenuation: true,
      }))
      scene.add(stars)

      // Orbiting spheres
      for (let i = 0; i < 8; i++) {
        const orb = new THREE.Mesh(
          new THREE.SphereGeometry(0.06, 8, 8),
          new THREE.MeshBasicMaterial({ color: new THREE.Color().setHSL(i / 8, 0.8, 0.6), transparent: true, opacity: 0.9 })
        )
        orbiters.push({ mesh: orb, radius: 2.0 + Math.random() * 1.5, speed: 0.3 + Math.random() * 0.7, phase: Math.random() * Math.PI * 2, tilt: Math.random() * Math.PI * 0.5 })
        scene.add(orb)
      }

      // Lights
      const p1 = new THREE.PointLight(0x4488ff, 2, 15)
      p1.position.set(2, 2, 2)
      scene.add(p1)
      const p2 = new THREE.PointLight(0xff4488, 1.5, 15)
      p2.position.set(-2, -1, 3)
      scene.add(p2)
      scene.add(new THREE.AmbientLight(0x111122, 0.5))
    },
    animate(t) {
      ico.rotation.x = t * 0.15
      ico.rotation.y = t * 0.25
      core.rotation.x = -t * 0.3
      core.rotation.y = t * 0.2
      core.scale.setScalar(1.0 + Math.sin(t * 2) * 0.1)
      coreMat.emissiveIntensity = 0.3 + Math.sin(t * 3) * 0.3

      for (let i = 0; i < rings.length; i++) {
        rings[i].rotation.x += 0.003 * (i + 1)
        rings[i].rotation.z += 0.002 * (i + 1)
        ;(rings[i].material as THREE.MeshBasicMaterial).opacity = 0.3 + Math.sin(t * 1.5 + i) * 0.2
      }

      for (const o of orbiters) {
        const angle = t * o.speed + o.phase
        o.mesh.position.set(Math.cos(angle) * o.radius, Math.sin(angle * 0.7) * o.radius * Math.sin(o.tilt), Math.sin(angle) * o.radius)
        o.mesh.scale.setScalar(0.8 + Math.sin(t * 3 + o.phase) * 0.3)
      }

      stars.rotation.y = t * 0.02
      stars.rotation.x = t * 0.01
      camera.position.x = Math.sin(t * 0.2) * 0.5
      camera.position.y = Math.cos(t * 0.15) * 0.3
      camera.lookAt(0, 0, 0)

      const hue = (t * 0.05) % 1
      icoMat.color.setHSL(hue, 0.7, 0.5)
    },
  })

  return <div ref={containerRef} style={{ width: '100vw', height: '100vh' }} />
}

import { useEffect, useRef } from 'react'
import * as THREE from 'three'

interface ThreeSceneOptions {
  setup: (scene: THREE.Scene, camera: THREE.PerspectiveCamera, renderer: THREE.WebGLRenderer) => void
  animate: (time: number, dt: number) => void
  cameraPosition?: [number, number, number]
  cameraLookAt?: [number, number, number]
  background?: number
}

export function useThreeScene(opts: ThreeSceneOptions) {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const scene = new THREE.Scene()
    scene.background = new THREE.Color(opts.background ?? 0x000000)

    const camera = new THREE.PerspectiveCamera(45, container.clientWidth / container.clientHeight, 0.1, 100)
    const pos = opts.cameraPosition ?? [0, 0, 5]
    camera.position.set(pos[0], pos[1], pos[2])
    const lookAt = opts.cameraLookAt ?? [0, 0, 0]
    camera.lookAt(lookAt[0], lookAt[1], lookAt[2])

    const renderer = new THREE.WebGLRenderer({ antialias: true })
    renderer.setSize(container.clientWidth, container.clientHeight)
    renderer.setPixelRatio(window.devicePixelRatio)
    container.appendChild(renderer.domElement)

    opts.setup(scene, camera, renderer)

    const clock = new THREE.Clock()
    let animId: number

    function loop() {
      animId = requestAnimationFrame(loop)
      const dt = clock.getDelta()
      const t = clock.getElapsedTime()
      opts.animate(t, dt)
      renderer.render(scene, camera)
    }
    loop()

    function onResize() {
      camera.aspect = container.clientWidth / container.clientHeight
      camera.updateProjectionMatrix()
      renderer.setSize(container.clientWidth, container.clientHeight)
    }
    window.addEventListener('resize', onResize)

    return () => {
      cancelAnimationFrame(animId)
      window.removeEventListener('resize', onResize)
      renderer.dispose()
      container.removeChild(renderer.domElement)
    }
  }, [])

  return containerRef
}

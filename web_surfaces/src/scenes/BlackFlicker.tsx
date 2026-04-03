import { useEffect, useRef } from 'react'

// CRAZY color-cycling neon with thick borders, flashes, and pulsing

export function BlackFlicker() {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')!
    let animId: number
    const startTime = performance.now()

    function resize() {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
    }
    resize()
    window.addEventListener('resize', resize)

    function hsl(h: number, s: number, l: number, a: number = 1) {
      return `hsla(${h % 360}, ${s}%, ${l}%, ${a})`
    }

    function draw() {
      animId = requestAnimationFrame(draw)
      const t = (performance.now() - startTime) / 1000
      const w = canvas.width
      const h = canvas.height

      // Cycling base hue
      const baseHue = (t * 40) % 360

      // Dark background with shifting hue
      ctx.fillStyle = hsl(baseHue, 60, 5)
      ctx.fillRect(0, 0, w, h)

      // Big center pulse
      const centerPulse = 0.3 + Math.sin(t * 2) * 0.2
      const grad = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.7)
      grad.addColorStop(0, hsl(baseHue + 30, 80, 25, centerPulse))
      grad.addColorStop(1, 'rgba(0,0,0,0)')
      ctx.fillStyle = grad
      ctx.fillRect(0, 0, w, h)

      // Edge glow — color cycling
      const edgeW = 30 + Math.sin(t * 3) * 15
      const edgeDefs = [
        { from: [0, 0, 0, edgeW * 4] as number[], phase: 0 },
        { from: [0, h, 0, h - edgeW * 4] as number[], phase: 1 },
        { from: [0, 0, edgeW * 4, 0] as number[], phase: 2 },
        { from: [w, 0, w - edgeW * 4, 0] as number[], phase: 3 },
      ]
      for (const edge of edgeDefs) {
        const pulse = 0.5 + Math.sin(t * 3 + edge.phase * 1.2) * 0.4
        const edgeHue = baseHue + edge.phase * 90
        const eg = ctx.createLinearGradient(edge.from[0], edge.from[1], edge.from[2], edge.from[3])
        eg.addColorStop(0, hsl(edgeHue, 100, 60, pulse))
        eg.addColorStop(1, 'rgba(0,0,0,0)')
        ctx.fillStyle = eg
        ctx.fillRect(0, 0, w, h)
      }

      // THICK neon border — color cycling
      const borderPulse = 0.7 + Math.sin(t * 3) * 0.3
      const borderHue = baseHue + 180
      ctx.shadowColor = hsl(borderHue, 100, 60, borderPulse)
      ctx.shadowBlur = 40 + Math.sin(t * 2) * 15
      ctx.strokeStyle = hsl(borderHue, 100, 60, borderPulse)
      ctx.lineWidth = 16 + Math.sin(t * 4) * 5
      ctx.strokeRect(8, 8, w - 16, h - 16)

      ctx.shadowBlur = 0
      ctx.strokeStyle = hsl(borderHue, 80, 80, borderPulse * 0.95)
      ctx.lineWidth = 5
      ctx.strokeRect(8, 8, w - 16, h - 16)

      const inner = 30 + Math.sin(t * 2) * 6
      ctx.strokeStyle = hsl(borderHue + 40, 100, 50, 0.35 + Math.sin(t * 2.5) * 0.25)
      ctx.lineWidth = 3
      ctx.strokeRect(inner, inner, w - inner * 2, h - inner * 2)

      // Traveling light — fast, bright
      const perim = 2 * (w + h)
      const pos = ((t * 300) % perim)
      let lx: number, ly: number
      if (pos < w) { lx = pos; ly = 0 }
      else if (pos < w + h) { lx = w; ly = pos - w }
      else if (pos < 2 * w + h) { lx = w - (pos - w - h); ly = h }
      else { lx = 0; ly = h - (pos - 2 * w - h) }

      const spotGrad = ctx.createRadialGradient(lx, ly, 0, lx, ly, 80)
      spotGrad.addColorStop(0, hsl(baseHue + 90, 100, 70, 0.9))
      spotGrad.addColorStop(0.4, hsl(baseHue + 90, 100, 50, 0.4))
      spotGrad.addColorStop(1, 'rgba(0,0,0,0)')
      ctx.fillStyle = spotGrad
      ctx.fillRect(0, 0, w, h)

      // Random bright flash
      if (Math.random() > 0.9) {
        ctx.fillStyle = hsl(baseHue + Math.random() * 180, 100, 50, 0.08 + Math.random() * 0.1)
        ctx.fillRect(0, 0, w, h)
      }
    }

    draw()
    return () => { cancelAnimationFrame(animId); window.removeEventListener('resize', resize) }
  }, [])

  return <canvas ref={canvasRef} style={{ display: 'block', width: '100vw', height: '100vh' }} />
}

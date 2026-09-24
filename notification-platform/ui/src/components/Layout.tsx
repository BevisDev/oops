import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { useLayoutEffect, useRef, useState } from 'react'

const links = [
  { to: '/', label: 'Overview', end: true },
  { to: '/sources', label: 'Sources' },
  { to: '/channels', label: 'Channels' },
  { to: '/templates', label: 'Templates' },
  { to: '/routing', label: 'Routing' },
  { to: '/recipients', label: 'Recipients' },
  { to: '/integrations', label: 'Integrations' },
  { to: '/logs', label: 'Logs' },
  { to: '/playground', label: 'Playground' },
]

export function Layout() {
  const location = useLocation()
  const navRef = useRef<HTMLElement>(null)
  const [indicatorY, setIndicatorY] = useState(0)

  useLayoutEffect(() => {
    const nav = navRef.current
    if (!nav) return
    const active = nav.querySelector<HTMLAnchorElement>('a.active')
    if (!active) return
    setIndicatorY(active.offsetTop)
  }, [location.pathname])

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark" aria-hidden>
            <svg viewBox="0 0 24 24" fill="none">
              <path d="M4 8h16v2H4V8zm0 4.5h12V14.5H4V12.5z" fill="#2dd4bf" />
              <circle cx="18.5" cy="13.5" r="2.5" fill="#f59e0b" />
            </svg>
          </div>
          <div className="brand-text">
            <strong>NotifyHub</strong>
            <span>notification platform</span>
          </div>
        </div>

        <nav className="nav" ref={navRef}>
          <div className="nav-indicator" style={{ transform: `translateY(${indicatorY}px)` }} />
          {links.map((l) => (
            <NavLink key={l.to} to={l.to} end={l.end} className={({ isActive }) => (isActive ? 'active' : undefined)}>
              {l.label}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-foot">
          POST /notification/notify
          <br />
          → Kafka → adapters
        </div>
      </aside>

      <main className="main">
        <Outlet />
      </main>
    </div>
  )
}

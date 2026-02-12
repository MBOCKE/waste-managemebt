import React from 'react'
import { Link } from 'react-router-dom'

export default function Header() {
  return (
    <header style={{ background: '#fff', borderBottom: '1px solid #e6e6e9', padding: '12px 24px' }}>
      <nav style={{ display: 'flex', gap: 16 }}>
        <Link to="/">Home</Link>
        <Link to="/user">User</Link>
        <Link to="/driver">Driver</Link>
        <Link to="/admin">Admin</Link>
        <Link to="/login">Login</Link>
      </nav>
    </header>
  )
}

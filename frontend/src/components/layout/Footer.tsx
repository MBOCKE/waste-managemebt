import React from 'react'

export default function Footer() {
  return (
    <footer style={{ borderTop: '1px solid #e6e6e9', padding: 12, marginTop: 24, textAlign: 'center', background: '#fff' }}>
      © {new Date().getFullYear()} API Project
    </footer>
  )
}

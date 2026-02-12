import React from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import UserDashboard from './pages/user/Dashboard'
import DriverRouteView from './pages/driver/RouteView'
import AdminDashboard from './pages/admin/AdminDashboard'
import Login from './pages/auth/Login'
import Header from './components/layout/Header'
import Footer from './components/layout/Footer'

export default function App() {
  return (
    <BrowserRouter>
      <Header />
      <main style={{ padding: 24 }}>
        <Routes>
          <Route path="/" element={<UserDashboard />} />
          <Route path="/user" element={<UserDashboard />} />
          <Route path="/driver" element={<DriverRouteView />} />
          <Route path="/admin" element={<AdminDashboard />} />
          <Route path="/login" element={<Login />} />
        </Routes>
      </main>
      <Footer />
    </BrowserRouter>
  )
}

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import {
  getCurrentUserProfile,
  getCurrentUserSession,
  signOut as cognitoSignOut,
} from "./authService";
import { hasPermission as userHasPermission } from "../admin/utils/permissions";

const AuthContext = createContext(null);

const ADMIN_GROUPS = ["super-admin", "admin", "manager", "kitchen"];

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [session, setSession] = useState(null);
  const [authLoading, setAuthLoading] = useState(true);

  const refreshAuth = async () => {
    try {
      setAuthLoading(true);
      const currentSession = await getCurrentUserSession();

      if (!currentSession) {
        setUser(null);
        setSession(null);
        return null;
      }

      const profile = await getCurrentUserProfile();
      setUser(profile);
      setSession(currentSession);
      return profile;
    } catch (error) {
      console.error("Auth refresh failed:", error);
      setUser(null);
      setSession(null);
      return null;
    } finally {
      setAuthLoading(false);
    }
  };

  const logout = () => {
    cognitoSignOut();
    setUser(null);
    setSession(null);
  };

  useEffect(() => {
    const refreshTimer = window.setTimeout(() => {
      refreshAuth();
    }, 0);

    return () => window.clearTimeout(refreshTimer);
  }, []);

  const value = useMemo(
    () => {
      const groups = user?.groups || [];
      const hasGroup = (...allowedGroups) =>
        allowedGroups.some((group) => groups.includes(group));

      return {
        user,
        session,
        groups,
        authLoading,
        isAuthenticated: Boolean(user),
        isAdmin: hasGroup(...ADMIN_GROUPS),
        hasGroup,
        hasPermission: (permission) => userHasPermission(groups, permission),
        refreshAuth,
        logout,
      };
    },
    [user, session, authLoading]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// The provider and its matching hook intentionally share this module.
// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }

  return context;
}

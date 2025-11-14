import { useContextMenu, Menu, Item, Separator, ItemParams } from 'react-contexify';
import React, { ReactNode, useEffect, useState } from 'react';
import 'react-contexify/dist/ReactContexify.css';
import './ContextMenu.css';


// Adapter for ContextMenuTrigger
interface ContextMenuTriggerProps {
  id: string;
  children: ReactNode;
}

export const ContextMenuTrigger: React.FC<ContextMenuTriggerProps> = ({ id, children }) => {
  const { show } = useContextMenu({ id });

  const handleContextMenu = (event: React.MouseEvent) => {
    event.preventDefault();
    show({ event });
  };

  return (
    <div onContextMenu={handleContextMenu}>
      {children}
    </div>
  );
};

// Adapter for ContextMenu
interface ContextMenuProps {
  id: string;
  className?: string;
  hideOnLeave?: boolean;
  animation?: string;
  children: ReactNode;
}

export const ContextMenu: React.FC<ContextMenuProps> = ({ id, className, children }) => {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    // Check if dark mode is active
    const checkDarkMode = () => {
      const htmlElement = document.documentElement;
      const hasDarkClass = htmlElement.classList.contains('dark');
      setIsDark(hasDarkClass);
    };

    // Initial check
    checkDarkMode();

    // Watch for class changes on html element
    const observer = new MutationObserver(checkDarkMode);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class']
    });

    return () => observer.disconnect();
  }, []);

  const menuClassName = `contexify ${isDark ? 'dark-menu' : ''} ${className || ''}`.trim();

  return (
    <Menu id={id} className={menuClassName}>
      {children}
    </Menu>
  );
};

// Adapter for ContextMenuItem
interface ContextMenuItemProps {
  onClick?: (args?: ItemParams) => void;
  disabled?: boolean;
  children: ReactNode;
}

export const ContextMenuItem: React.FC<ContextMenuItemProps> = ({ onClick, disabled, children }) => {
  return (
    <Item onClick={onClick} disabled={disabled}>
      {children}
    </Item>
  );
};
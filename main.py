import os
import shutil
import tkinter as tk
import string
from tkinter import messagebox


def find_game_directory():
    game_folder = "Sid Meier's Civilization V"
    # TODO: this is optimizable :V
    search_paths = [
        # when installed on C drive
        os.path.join("Program Files (x86)", "Steam", "steamapps", "common", game_folder, "Assets", "DLC"),
        # when installed on diffrent drive
        os.path.join("SteamLibrary", "steamapps", "common", game_folder, "Assets", "DLC")
    ]

    # Get all available drive letters
    drives = [f"{d}:\\" for d in string.ascii_uppercase if os.path.exists(f"{d}:\\")]

    for drive in drives:
        for search_path in search_paths:
            potential_path = os.path.join(drive, search_path)
            print(f"Checking path: {potential_path}")  # Debug print
            if os.path.exists(potential_path):
                print(f"Found game directory at: {potential_path}")  # Debug print
                return potential_path

    return None


def install_dlc():
    # UI_bc1 is the folder that contains the custom UI files and .xml file is just a langauge pack
    DLC_file = "EUI_FILES/UI_bc1"
    XML_file = "EUI_FILES/EUI_text_en_us.xml"

    dest_a = find_game_directory() + "/UI_bc1"
    print(dest_a)
    dest_b = os.path.expanduser("~/Documents/My Games/Sid Meier's Civilization 5/Text/EUI_text_en_us.xml")

    # Ensure destination folder exists
    if not os.path.exists(os.path.dirname(dest_a)):
        messagebox.showerror("Error", "Cannot find game DLC folder!")
        return
    if not os.path.exists(os.path.dirname(dest_b)):
        messagebox.showerror("Error", "Cannot find text folder!")
        return

    # Try installing dlc folder
    try:
        if os.path.exists(dest_a):
            messagebox.showinfo("bruh", "EUI is already installed !")
        else:
            shutil.copytree(DLC_file, dest_a)
            messagebox.showinfo("EUI has been successfully installed !   ", f"Installed {dest_a})")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to copy {DLC_file}: {e}")

    # Try installing langauge pack folder
    try:
        if os.path.exists(dest_b):
            messagebox.showinfo("bruh", "EUI langauge pack is already installed !")
        else:
            shutil.copy2(XML_file, dest_b)
            messagebox.showinfo("EUI langauge pack has been successfully installed !   ", f"Installed {dest_b})")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to copy {XML_file}: {e}")


def delete_dlc_folder():
    dest_a = find_game_directory() + "\\UI_bc1"
    print(dest_a)
    dest_b = os.path.expanduser("~/Documents/My Games/Sid Meier's Civilization 5/Text/EUI_text_en_us.xml")

    # Try deleting custom UI folder
    try:
        shutil.rmtree(dest_a)
        messagebox.showinfo("EUI has been successfully deleted !   ", f"Deleted {dest_a})")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to delete {dest_a}: {e}")

    # Try deleting langauge pack folder
    try:
        os.remove(dest_b)
        messagebox.showinfo("EUI language pack been successfully deleted !   ", f"Deleted {dest_b})")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to delete {dest_b}: {e}")


def delete_cache_folder():
    # Game cache folder
    dest_c = os.path.expanduser("~/Documents/My Games/Sid Meier's Civilization 5/cache")

    # Try deleting game cache
    try:
        if not os.path.exists(dest_c):
            messagebox.showinfo("bruh", "Game cache is already deleted !")
        else:
            shutil.rmtree(dest_c)
            messagebox.showinfo("Game cache has been successfully deleted !   ", f"Deleted {dest_c}")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to delete {dest_c}: {e}")


# Create the main window
root = tk.Tk()
root.title("EUI KiraInstaller")

button_font = ('Helvetica', 20)

# Install button
move_button = tk.Button(root, text="Install EUI", command=install_dlc, font=button_font)
move_button.pack(pady=20)

# Remove dlc button
delete_button = tk.Button(root, text="Delete EUI", command=delete_dlc_folder, font=button_font)
delete_button.pack(pady=20)

# Clear cache button
clearcache_button = tk.Button(root, text="Clear Game Cache", command=delete_cache_folder, font=button_font)
clearcache_button.pack(pady=20)

# Center the main window
height = 300
width = 260
x = (root.winfo_screenwidth() // 2) - (width // 2)
y = (root.winfo_screenheight() // 2) - (height // 2)
root.geometry(f"{width}x{height}+{x}+{y}")

# Run the application
root.mainloop()

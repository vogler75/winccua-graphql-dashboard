from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="winccunified-python",
    version="1.0.0",
    author="Andreas Vogler",
    description="Python client library for WinCC Unified GraphQL API",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: ISC License (ISCL)",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Monitoring",
        "Topic :: System :: Systems Administration",
    ],
    python_requires=">=3.8",
    install_requires=[
        "websockets>=11.0.0",
        "aiohttp>=3.8.0",
    ],
    keywords="wincc-unified graphql client websocket subscription hmi",
    project_urls={
        "Source": "https://github.com/your-username/winccua-graphql-dashboard",
        "Tracker": "https://github.com/your-username/winccua-graphql-dashboard/issues",
    },
)
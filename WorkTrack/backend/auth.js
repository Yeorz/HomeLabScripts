import jwt from "jsonwebtoken";

// Validate JWT secret on module load
if (!process.env.JWT_SECRET) {
  throw new Error('FATAL: JWT_SECRET environment variable not set. Set with: export JWT_SECRET=$(openssl rand -base64 32)');
}

export function auth(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.sendStatus(401);
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.sendStatus(403);
  }
}
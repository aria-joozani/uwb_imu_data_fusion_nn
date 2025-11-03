function flow = extract_flow(df)
    t_flow = deleteNAN(df.t_flow(:));
    dx = deleteNAN(df.deltaX(:));
    dy = deleteNAN(df.deltaY(:));
    flow = [t_flow, dx, dy];
end